# Stage 1: Python app for recording
FROM python:3.14-slim AS recorder

# Install ffmpeg and other system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ffmpeg \
    tzdata \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set timezone to KST
ENV TZ=Asia/Seoul
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY src/record.py .
COPY src/touch.py .


# Make scripts executable
RUN chmod +x record.py touch.py

# Create programs directory
RUN mkdir -p /app/programs

# Set entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

# Stage 2: Bottle feed service
FROM python:3.11-slim AS feed

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ffmpeg \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Set timezone to KST
ENV TZ=Asia/Seoul
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy feed service
COPY src/feed.py .


# Create directories
RUN mkdir -p /app/recordings
RUN mkdir -p /app/logo

# Expose port 8080
EXPOSE 8080

# Run feed service
CMD ["python3", "feed.py"]

