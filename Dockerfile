# Use Java 21 runtime
FROM eclipse-temurin:21-jre-alpine

# Set working folder inside container
WORKDIR /app

# Copy your compiled .jar file into container
COPY backend/target/employee-management-app-0.0.1-SNAPSHOT.jar app.jar

# Open port 8080
EXPOSE 8080

# Run your app
ENTRYPOINT ["java", "-jar", "app.jar"]
