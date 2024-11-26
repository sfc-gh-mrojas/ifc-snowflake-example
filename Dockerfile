# Use Ubuntu 22.04 as the base image
FROM ubuntu:22.04

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Install system dependencies, Python, and pip
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    build-essential \
    libboost-all-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip3 install --no-cache-dir ifcopenshell Flask snowflake-snowpark-python

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . .

# Expose port 5000 for Flask
EXPOSE 5000

# Run the Flask application
CMD ["python3", "app.py"]
