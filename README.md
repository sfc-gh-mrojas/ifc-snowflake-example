# Using IFC Open Shell in Snowflake

IfcOpenShell helps you develop digital platforms for the built environment.
Read, write, and modify Building Information Models using IFC,
a diverse digital language from design to construction and beyond.

IfcOpenShell is compile on an specific version of Ubuntu, and we can just use that specific version with Snowpark Container Services (SPCS)

This repository has a small example showing how you can easily leverage SPCS to use this library.

In this example we assume that you will provision your model files on an stage, so you can read any model file on that stage.

# Building Instructions

## Prerequisite Preparations
Ensure you have:
   - Snowflake account with AccountAdmin role
   - Docker installed
   - Access to the necessary model files
   - A local machine with appropriate permissions

## 1. Snowflake Setup

### A. Role and Database Configuration
```bash
# Connect to Snowflake as AccountAdmin
# Run the following SQL commands:
use role accountadmin;

# Create test role
CREATE ROLE test_role;

# Create test database
CREATE DATABASE IF NOT EXISTS ifc_test_db;
GRANT OWNERSHIP ON DATABASE ifc_test_db TO ROLE test_role COPY CURRENT GRANTS;
GRANT OWNERSHIP ON SCHEMA ifc_test_db.public TO ROLE test_role COPY CURRENT GRANTS;
```

### B. Warehouse and Compute Pool Setup
```sql
# Create small warehouse
CREATE OR REPLACE WAREHOUSE load_wh WITH
  WAREHOUSE_SIZE='X-SMALL';
GRANT USAGE ON WAREHOUSE load_wh TO ROLE test_role;

# Grant service endpoint binding
GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE test_role;

# Create compute pool using X64 arch
CREATE COMPUTE POOL ifc_compute_pool
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = CPU_X64_XS;
GRANT USAGE, MONITOR ON COMPUTE POOL ifc_compute_pool TO ROLE test_role;
```

### C. User and Role Management
```sql
# Assign role to specific user (replace mrojas with your username)
GRANT ROLE test_role TO USER mrojas;
```

## 2. Stage and Repository Setup
```sql
# Create stage for model files
CREATE STAGE ifc_stage;

# Upload IFC model (replace with your actual path)
PUT file:///path/to/model/model.ifc @ifc_stage 
    auto_compress=false 
    overwrite=true;

# Create image repository
CREATE IMAGE REPOSITORY IF NOT EXISTS ifc_image_repository;
```

## 3. Docker Image Preparation

### A. Docker Login
```bash
# Login to Snowflake image repository
docker login <image_repository> -u <your_username>
```

### B. Build Docker Image
Ensure you have a Dockerfile prepared with your IFC processing logic. Then build:
```bash
docker build --platform=linux/amd64 \
    -t <image_repository>/ifc_in_docker:latest .
```

### C. Push Docker Image
```bash
docker push <image_repository>/ifc_in_docker:latest
```

## 4. Snowflake Service Creation
```sql
CREATE SERVICE ifc_service
  IN COMPUTE POOL IFC_COMPUTE_POOL
  FROM SPECIFICATION $$
    spec:
      containers:
      - name: ifccontainer
        image: /ifc_test_db/public/ifc_image_repository/ifc_in_docker:latest
        volumeMounts:
        - name: models
          mountPath: /opt/models
      endpoints:
      - name: ifcendpoint
        port: 5000
        public: true
      volumes:
      - name: models
        source: "@ifc_stage"
      $$
   QUERY_WAREHOUSE = 'load_wh'
   MIN_INSTANCES=1
   MAX_INSTANCES=1;
```

## 5. Verification and Testing
```sql
# Check service status
SELECT SYSTEM$GET_SERVICE_STATUS('ifc_service');

# View service logs
SELECT SYSTEM$GET_SERVICE_LOGS('ifc_service', 0, 'ifccontainer');

# Create test function
CREATE OR REPLACE FUNCTION test_ifc (input varchar)
  RETURNS varchar
  SERVICE=ifc_service
  ENDPOINT=ifcendpoint
  AS '/load_ifc';

# Test the function
SELECT test_ifc('model.ifc');
```

## Additional Recommendations
- Ensure your Docker image includes all necessary dependencies for IFC processing
- The `/load_ifc` endpoint should be implemented in your service to handle IFC file processing
- Replace placeholders like `<image_repository>`, `<your_username>`, and file paths with your specific values
- Validate each step and ensure proper permissions and network access

## Troubleshooting
- Verify Docker image compatibility with Snowflake's platform
- Check network connectivity and firewall settings
- Ensure all required permissions are granted
- Review Snowflake and Docker logs for any error messages

Would you like me to elaborate on any specific part of these build instructions?
# ifc-snowflake-example
