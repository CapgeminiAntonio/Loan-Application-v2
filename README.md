# Loan Application System

## Set up PostgreSQL and pgAdmin (no Docker)

Install PostgreSQL 16 and pgAdmin 4 for Windows. During PostgreSQL installation, create or configure a database login with username `loans` and password `loans`, and ensure the PostgreSQL service is running on port `5432`.

In pgAdmin, create the `loans` database owned by the `loans` login, then register/connect to the server using:

- Host: `localhost`
- Port: `5432`
- Maintenance database: `postgres`
- Username: `loans`
- Password: `loans`

The backend connects to `jdbc:postgresql://localhost:5432/loans`. Flyway creates the schema automatically when the backend starts. Start with the `dev` profile to load the fictional demo users and applications.

## Reset database

To reset the schema and demo data, drop and recreate the `loans` database in pgAdmin, then restart the backend with the `dev` profile. Flyway applies the migrations and seed data on startup. The optional `scripts/reset-db.sh` uses local PostgreSQL command-line tools (`dropdb` and `createdb`); run it in Git Bash or WSL with the PostgreSQL admin credentials configured (by default, `PGUSER=postgres`). The `loans` login must exist and own the recreated database.

## Run backend

```powershell
cd backend
./mvnw.cmd spring-boot:run -Dspring-boot.run.arguments=--spring.profiles.active=dev
```
