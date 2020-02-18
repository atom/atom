FROM node:8-slim

LABEL "com.github.actions.name"="auto-sprint"
LABEL "com.github.actions.description"="Add opened pull requests and assigned issues to the current sprint project"
LABEL "com.github.actions.icon"="list"
LABEL "com.github.actions.color"="white"

# Copy the package.json and package-lock.json
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy the rest of your action's code
COPY . /

# Run `node /index.js`
ENTRYPOINT ["node", "/index.js"]
