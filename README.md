# Loan Application System

## Set up PostgreSQL and pgAdmin

Install PostgreSQL 16 and pgAdmin 4 for Windows, and ensure the PostgreSQL service is running on port `5432`. The settings in `backend/src/main/resources/application.yml` connect to:

- Host and port: `localhost:5432`
- Database: `personal-loan-v2`
- Username: `postgres`
- Password: your local PostgreSQL password

In pgAdmin, create the `personal-loan-v2` database owned by `postgres` if it does not already exist. The backend listens on port `8080`. Flyway creates the schema automatically when the backend starts; use the `dev` profile to load the fictional demo users and applications.

Set your own PostgreSQL password in the environment before starting the backend. This overrides the local default in `application.yml` and should not be committed or shared:

```powershell
$env:SPRING_DATASOURCE_PASSWORD = "<your-local-postgres-password>"
```

## Reset database

To reset the schema and demo data, drop and recreate the `personal-loan-v2` database in pgAdmin, then restart the backend with the `dev` profile. Flyway reapplies the migrations and seed data on startup. Note: `scripts/reset-db.sh` currently resets a separate `loans` database owned by `loans`; it does not reset the database configured in `application.yml`.

## Run backend

```powershell
cd backend
./mvnw.cmd spring-boot:run -Dspring-boot.run.arguments=--spring.profiles.active=dev
```
