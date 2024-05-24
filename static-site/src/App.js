import React, { useState } from "react";
import axios from "axios";
import "./App.css";
import additionalImage from './robot_pictures.png'; // Ensure this path is correct

const App = () => {
  const [prompt, setPrompt] = useState("");
  const [model] = useState("stabilityai/stable-diffusion-2");
  const [imageUrl, setImageUrl] = useState("");
  const [loading, setLoading] = useState(false);
  const [showInitialImage, setShowInitialImage] = useState(true);

  const handlePromptChange = (e) => {
    setPrompt(e.target.value);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setShowInitialImage(false);
    try {
      const response = await axios.post(
        "/generate",
        { model, prompt },
        {
          headers: {
            "Content-Type": "application/json",
            "Authorization": "dummy_value"
          },
        }
      );

      const output = response.data.output;
      const s3KeyMatch = output.match(/Uploaded (.+) to (.+)\/(.+\.png)/);

      if (s3KeyMatch) {
        const s3Bucket = s3KeyMatch[2].trim();
        const s3File = s3KeyMatch[3].trim();
        const s3Url = `https://${s3Bucket}.s3.amazonaws.com/${s3File}`;
        setImageUrl(s3Url);
      } else {
        console.error("Could not extract S3 URL from response");
      }
    } catch (error) {
      console.error("Error generating image:", error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>Dreamcanvas Image Generator</h1>
        <div className="image-placeholder-container">
          {showInitialImage ? (
            <div className="image-wrapper">
              <img src={additionalImage} alt="Additional" className="additional-image" />
            </div>
          ) : (
            <>
              {loading ? (
                <div className="image-placeholder">
                  <div className="spinner"></div>
                </div>
              ) : (
                <div className="image-wrapper">
                  <img src={imageUrl} alt="Generated result" />
                  <a href={imageUrl} download target="_blank" rel="noopener noreferrer">
                    <div className="download-icon">⬇</div>
                  </a>
                </div>
              )}
            </>
          )}
        </div>
        <form onSubmit={handleSubmit} className="form-container">
          <div className="input-container">
            <input
              type="text"
              id="prompt"
              value={prompt}
              onChange={handlePromptChange}
              placeholder="Enter your prompt"
            />
            <button type="submit" className="generate-button">Generate Image</button>
          </div>
        </form>
      </header>
    </div>
  );
};

export default App;
