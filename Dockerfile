# Stage 1: Build
FROM maven:3.8.5-openjdk-17 AS build

WORKDIR /app

# Copier pom.xml et télécharger les dépendances
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copier le code source
COPY src ./src

# Construire l'application (skip tests pour éviter les erreurs de connexion DB)
RUN mvn clean package -DskipTests

# Stage 2: Runtime
FROM openjdk:17-jdk-slim

WORKDIR /app

# Installer dockerize pour attendre que les services soient prêts
RUN apt-get update && apt-get install -y wget \
    && wget https://github.com/jwilder/dockerize/releases/download/v0.6.1/dockerize-linux-amd64-v0.6.1.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-linux-amd64-v0.6.1.tar.gz \
    && rm dockerize-linux-amd64-v0.6.1.tar.gz \
    && apt-get clean

# Copier le JAR depuis le stage de build
COPY --from=build /app/target/*.jar app.jar

# Exposer le port
EXPOSE 8080

# Point d'entrée avec dockerize pour attendre MySQL et MongoDB
ENTRYPOINT ["dockerize", \
    "-wait", "tcp://employee_db:3306", \
    "-wait", "tcp://employee_mongo:27017", \
    "-timeout", "60s", \
    "java", "-jar", "app.jar"]
