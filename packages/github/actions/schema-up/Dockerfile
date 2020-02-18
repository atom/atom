FROM node:8-slim

LABEL "com.github.actions.name"="schema-up"
LABEL "com.github.actions.description"="Update GraphQL schema and adjust Relay files"
LABEL "com.github.actions.icon"="arrow-up-right"
LABEL "com.github.actions.color"="blue"

RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

# Copy the package.json and package-lock.json
COPY package*.json /

# Install dependencies
RUN npm ci

# Copy the rest of your action's code
COPY * /

# Run `node /index.js`
ENTRYPOINT ["node", "/index.js"]
