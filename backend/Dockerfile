FROM node:22-alpine

WORKDIR /usr/src/app

COPY package*.json ./

RUN npm install --omit=dev

COPY . .

# Fotos enviadas pelos cidadãos (montado como volume no docker-compose)
RUN mkdir -p /usr/src/app/uploads

EXPOSE 3000

CMD ["node", "src/index.js"]
