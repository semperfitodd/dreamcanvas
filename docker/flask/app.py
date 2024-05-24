import logging
import os
from flask import Flask, request, jsonify
from kubernetes import client, config
from kubernetes.stream import stream

app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO)

# Load Kubernetes configuration
try:
    if os.getenv("KUBERNETES_SERVICE_HOST"):
        config.load_incluster_config()  # Load in-cluster config for Kubernetes
    else:
        config.load_kube_config()  # Load kube config from default location
    api_instance = client.CoreV1Api()  # Initialize CoreV1Api instance
except Exception as e:
    logging.error(f"Error loading Kubernetes configuration: {e}")

deployment_name = 'stablediffusion-dreamcanvas'
namespace = 'dreamcanvas'


def get_pod_name_from_deployment(deployment_name, namespace):
    """
    Get the pod name from the deployment name and namespace.
    """
    try:
        api_apps = client.AppsV1Api()  # Initialize AppsV1Api instance
        pods = api_instance.list_namespaced_pod(namespace)  # List all pods in the namespace
        for pod in pods.items:
            logging.info(f"Pod metadata: {pod.metadata}")
            if pod.metadata.generate_name and deployment_name in pod.metadata.generate_name:
                logging.info(f"Found pod: {pod.metadata.name}")
                return pod.metadata.name  # Return the pod name if found
        logging.error(f"No pod found for deployment: {deployment_name}")
    except Exception as e:
        logging.error(f"Error fetching pod name: {e}")
    return None


@app.route('/', methods=['GET'])
def health_check():
    """
    Health check endpoint.
    """
    return "Healthy", 200


def execute_stablediffusion(pod_name, model, prompt):
    """
    Execute stable diffusion command in the specified pod.
    """
    command = ["/usr/local/bin/docker-entrypoint.py", "--model", model, "--prompt", prompt]
    try:
        resp = stream(api_instance.connect_get_namespaced_pod_exec,
                      pod_name,
                      namespace,
                      command=command,
                      stderr=True, stdin=False,
                      stdout=True, tty=False)
        return resp
    except Exception as e:
        logging.error(f"Error executing stable diffusion: {e}")
        return str(e)


@app.route('/generate', methods=['POST'])
def generate_image():
    """
    Generate image endpoint.
    """
    data = request.get_json()
    model = data.get('model', 'stabilityai/stable-diffusion-2')
    prompt = data.get('prompt', 'cartoon purple ape')
    pod_name = get_pod_name_from_deployment(deployment_name, namespace)
    if not pod_name:
        return jsonify({"error": "Pod not found"}), 500
    try:
        response = execute_stablediffusion(pod_name, model, prompt)
        return jsonify({"output": response})
    except Exception as e:
        logging.error(f"Error executing stable diffusion: {e}")
        return jsonify({"error": str(e)}), 500


@app.errorhandler(404)
def page_not_found(e):
    """
    Handle 404 errors.
    """
    return jsonify({"error": "Endpoint not found"}), 404


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)  # Run the Flask app
