# Use the official Python 3.11 slim image as the base image
FROM python:3.11-slim

# Copy the requirements.txt file into the /app directory in the container
COPY requirements.txt /app/requirements.txt

# Set the working directory to /app
WORKDIR /app

# Install the Python dependencies specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy the entire contents of the current directory into the /app directory in the container
COPY . /app

# Expose port 8080 for the container
EXPOSE 8080

# Specify the command to run the application
CMD ["python", "app.py"]
