# Stage 1: Build the React app
FROM node:18-alpine AS build

# Set the working directory inside the container
WORKDIR /app

# Copy package.json and yarn.lock / package-lock.json to install dependencies
COPY package.json yarn.lock ./

# Install dependencies (this will not install devDependencies for production build)
RUN yarn install

# Copy the rest of the application code
COPY . .

# Build the React app for production
RUN yarn build

# Stage 2: Serve the production build
FROM nginx:alpine

# Set the working directory inside the container
WORKDIR /usr/share/nginx/html

# Remove the default nginx static assets
RUN rm -rf ./*

# Copy the production build files from the build stage
COPY --from=build /app/build .

# Expose port 80
EXPOSE 80

# Start Nginx server
CMD ["nginx", "-g", "daemon off;"]