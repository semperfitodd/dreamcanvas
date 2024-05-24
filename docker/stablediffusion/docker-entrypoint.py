#!/usr/bin/env python
import argparse
import datetime
import inspect
import os
import re
import warnings

import boto3
import numpy as np
import torch
from PIL import Image
from diffusers import (
    AutoPipelineForText2Image,
    AutoPipelineForImage2Image,
    AutoPipelineForInpainting,
    DiffusionPipeline,
    OnnxStableDiffusionPipeline,
    OnnxStableDiffusionInpaintPipeline,
    OnnxStableDiffusionImg2ImgPipeline,
    schedulers,
)


# Function to get the current ISO date-time
def iso_date_time():
    return datetime.datetime.now().isoformat()


# Function to load an image from a given path
def load_image(path):
    image = Image.open(os.path.join("input", path)).convert("RGB")
    print(f"Loaded image from {path}:", iso_date_time(), flush=True)
    return image


# Function to remove unused arguments from a dictionary
def remove_unused_args(p):
    params = inspect.signature(p.pipeline).parameters.keys()
    args = {
        "prompt": p.prompt,
        "negative_prompt": p.negative_prompt,
        "image": p.image,
        "mask_image": p.mask,
        "height": p.height,
        "width": p.width,
        "num_images_per_prompt": p.samples,
        "num_inference_steps": p.steps,
        "guidance_scale": p.scale,
        "image_guidance_scale": p.image_scale,
        "strength": p.strength,
        "generator": p.generator,
    }
    return {k: args[k] for k in params if k in args}


# Function to set up the Stable Diffusion pipeline
def stable_diffusion_pipeline(p):
    p.dtype = torch.float16 if p.half else torch.float32

    if p.onnx:
        p.diffuser = OnnxStableDiffusionPipeline
        p.revision = "onnx"
    else:
        p.diffuser = DiffusionPipeline
        p.revision = "fp16" if p.half else "main"

    autos = argparse.Namespace(
        sd=["StableDiffusionPipeline"],
        sdxl=["StableDiffusionXLPipeline"],
    )

    config = DiffusionPipeline.load_config(p.model)
    is_auto_pipeline = config["_class_name"] in autos.sd or config["_class_name"] in autos.sdxl

    if is_auto_pipeline:
        p.diffuser = AutoPipelineForText2Image

    if p.image is not None:
        if p.revision == "onnx":
            p.diffuser = OnnxStableDiffusionImg2ImgPipeline
        elif is_auto_pipeline:
            p.diffuser = AutoPipelineForImage2Image
        p.image = load_image(p.image)

    if p.mask is not None:
        if p.revision == "onnx":
            p.diffuser = OnnxStableDiffusionInpaintPipeline
        elif is_auto_pipeline:
            p.diffuser = AutoPipelineForInpainting
        p.mask = load_image(p.mask)

    if p.token is None:
        with open("token.txt") as f:
            p.token = f.read().strip()

    if p.seed == 0:
        p.seed = torch.random.seed()

    if p.revision == "onnx":
        p.seed = p.seed >> 32 if p.seed > 2 ** 32 - 1 else p.seed
        p.generator = np.random.RandomState(p.seed)
    else:
        p.generator = torch.Generator(device=p.device).manual_seed(p.seed)

    print("Load pipeline start:", iso_date_time(), flush=True)

    with warnings.catch_warnings():
        warnings.filterwarnings("ignore", category=UserWarning)
        warnings.filterwarnings("ignore", category=FutureWarning)
        pipeline = p.diffuser.from_pretrained(
            p.model,
            torch_dtype=p.dtype,
            revision=p.revision,
            use_auth_token=p.token,
        ).to(p.device)

    if p.scheduler is not None:
        scheduler = getattr(schedulers, p.scheduler)
        pipeline.scheduler = scheduler.from_config(pipeline.scheduler.config)

    if p.skip:
        pipeline.safety_checker = None

    if p.attention_slicing:
        pipeline.enable_attention_slicing()

    if p.xformers_memory_efficient_attention:
        pipeline.enable_xformers_memory_efficient_attention()

    if p.vae_slicing:
        pipeline.enable_vae_slicing()

    if p.vae_tiling:
        pipeline.enable_vae_tiling()

    p.pipeline = pipeline

    print("Loaded models after:", iso_date_time(), flush=True)

    return p


# Function to upload a file to an S3 bucket
def upload_to_s3(file_path, bucket_name, s3_key):
    s3 = boto3.client('s3')
    s3.upload_file(file_path, bucket_name, s3_key)
    print(f"Uploaded {file_path} to {bucket_name}/{s3_key}")
    return f"https://{bucket_name}.s3.amazonaws.com/{s3_key}"


# Function to perform stable diffusion inference
def stable_diffusion_inference(p):
    bucket_name = os.environ.get('S3_BUCKET')
    if not bucket_name:
        raise ValueError("S3_BUCKET environment variable is not set")

    prefix = (
        re.sub(r"[\\/:*?\"<>|]", "", p.prompt)
        .replace(" ", "_")
        .encode("utf-8")[:170]
        .decode("utf-8", "ignore")
    )
    output_urls = []
    for j in range(p.iters):
        result = p.pipeline(**remove_unused_args(p))

        for i, img in enumerate(result.images):
            idx = j * p.samples + i + 1
            out = f"{prefix}__steps_{p.steps}__scale_{p.scale:.2f}__seed_{p.seed}__n_{idx}.png"
            out_path = os.path.join("output", out)
            img.save(out_path)
            s3_url = upload_to_s3(out_path, bucket_name, out)
            output_urls.append(s3_url)

    print("Completed pipeline:", iso_date_time(), flush=True)
    return {"output": output_urls}


# Function to parse command line arguments
def parse_args():
    parser = argparse.ArgumentParser(description="Create images from a text prompt.")
    parser.add_argument("--attention-slicing", action="store_true",
                        help="Use less memory at the expense of inference speed")
    parser.add_argument("--device", type=str, default="cuda", help="The cpu or cuda device to use to render images")
    parser.add_argument("--half", action="store_true", help="Use float16 (half-sized) tensors instead of float32")
    parser.add_argument("--height", type=int, default=512, help="Image height in pixels")
    parser.add_argument("--image", type=str, help="The input image to use for image-to-image diffusion")
    parser.add_argument("--image-scale", type=float, help="How closely the image should follow the original image")
    parser.add_argument("--iters", type=int, default=1, help="Number of times to run pipeline")
    parser.add_argument("--mask", type=str, help="The input mask to use for diffusion inpainting")
    parser.add_argument("--model", type=str, default="CompVis/stable-diffusion-v1-4",
                        help="The model used to render images")
    parser.add_argument("--negative-prompt", type=str, help="The prompt to not render into an image")
    parser.add_argument("--onnx", action="store_true", help="Use the onnx runtime for inference")
    parser.add_argument("--prompt", type=str, help="The prompt to render into an image")
    parser.add_argument("--samples", type=int, default=1, help="Number of images to create per run")
    parser.add_argument("--scale", type=float, default=7.5, help="How closely the image should follow the prompt")
    parser.add_argument("--scheduler", type=str, help="Override the scheduler used to denoise the image")
    parser.add_argument("--seed", type=int, default=0, help="RNG seed for repeatability")
    parser.add_argument("--skip", action="store_true", help="Skip the safety checker")
    parser.add_argument("--steps", type=int, default=50, help="Number of sampling steps")
    parser.add_argument("--strength", type=float, default=0.75, help="Diffusion strength to apply to the input image")
    parser.add_argument("--token", type=str, help="Huggingface user access token")
    parser.add_argument("--vae-slicing", action="store_true",
                        help="Use less memory when creating large batches of images")
    parser.add_argument("--vae-tiling", action="store_true",
                        help="Use less memory when creating ultra-high resolution images")
    parser.add_argument("--width", type=int, default=512, help="Image width in pixels")
    parser.add_argument("--xformers-memory-efficient-attention", action="store_true",
                        help="Use less memory but require the xformers library")
    parser.add_argument("prompt0", metavar="PROMPT", type=str, nargs="?", help="The prompt to render into an image")

    args = parser.parse_args()

    if args.prompt0 is not None:
        args.prompt = args.prompt0

    return args


# Main function to run the script
def main():
    args = parse_args()
    pipeline = stable_diffusion_pipeline(args)
    stable_diffusion_inference(pipeline)


if __name__ == "__main__":
    main()
