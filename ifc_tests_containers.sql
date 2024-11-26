
use role accountadmin;

CREATE ROLE test_role;

CREATE DATABASE IF NOT EXISTS ifc_test_db;
GRANT OWNERSHIP ON DATABASE ifc_test_db TO ROLE test_role COPY CURRENT GRANTS;
GRANT OWNERSHIP ON SCHEMA ifc_test_db.public TO ROLE test_role COPY CURRENT GRANTS;

CREATE OR REPLACE WAREHOUSE load_wh WITH
  WAREHOUSE_SIZE='X-SMALL';
GRANT USAGE ON WAREHOUSE load_wh TO ROLE test_role;

GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE test_role;



CREATE COMPUTE POOL ifc_compute_pool
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = CPU_X64_XS;
GRANT USAGE, MONITOR ON COMPUTE POOL ifc_compute_pool TO ROLE test_role;

GRANT ROLE test_role TO USER mrojas;

CREATE STAGE ifc_stage;
PUT file:///Users/mrojas/checker/ifc/ifc_example/model.ifc @ifc_stage auto_compress=false overwrite=true;

CREATE IMAGE REPOSITORY IF NOT EXISTS ifc_image_repository;

SHOW COMPUTE POOLS; --or DESCRIBE COMPUTE POOL ifc_compute_pool;
SHOW WAREHOUSES;
SHOW IMAGE REPOSITORIES;
SHOW STAGES;



-- docker commands

-- docker login sfpscogs-migration-aws-east.registry.snowflakecomputing.com/ifc_test_db/public/ifc_image_repository -u MROJAS

-- building the image:
-- docker build --platform=linux/amd64 -t <local_repository>/python-jupyter-snowpark:latest .
-- docker build --platform=linux/amd64 -t sfpscogs-migration-aws-east.registry.snowflakecomputing.com/ifc_test_db/public/ifc_image_repository/ifc_in_docker:latest .

-- pushing the image to the repository:
-- docker push  sfpscogs-migration-aws-east.registry.snowflakecomputing.com/ifc_test_db/public/ifc_image_repository/ifc_in_docker:latest


drop service ifc_service;

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


SELECT SYSTEM$GET_SERVICE_STATUS('ifc_service');

SELECT SYSTEM$GET_SERVICE_LOGS('ifc_service', 0, 'ifccontainer');

CREATE OR REPLACE FUNCTION test_ifc (input varchar)
  RETURNS varchar
  SERVICE=ifc_service
  ENDPOINT=ifcendpoint
  AS '/load_ifc';


  select test_ifc('model.ifc');