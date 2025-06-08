#!bin/bash

negrita='\e[1m'

verde='\e[32m'

rojo='\e[31m'

NC='\e[0m'

azul='\e[34m'

amarillo='\e[33'

echo -e "${azul}------------------------------------CREAR LOCAL-PATH------------------------------------${NC}"

kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

echo -e "${azul}--------------------------------INSTALAR POSTGRESQL---------------------------------${NC}"

kubectl create namespace monitoreo

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm install my-postgresql bitnami/postgresql --namespace monitoreo

echo -e "${azul} Esperando a que PostgreSQL esté listo...${NC}"
until kubectl get pods -n monitoreo | grep my-postgresql | grep -q 'Running'; do
  sleep 5
done
echo -e "${verde} PostgreSQL está listo.${NC}"

echo -e "${azul}-------------------------------CREACION DE BASE DE DATOS Y USUARIO-------------------------------${NC}"

#---------------------CONTRASEÑA DE POSTGRE----------------

pswd_pg=$(kubectl get secret my-postgresql -n monitoreo -o jsonpath="{.data.postgres-password}" | base64 --decode)

#------------------------------------------------

read -p "nombre de la base de datos: " db_name

read -p "nombre de usuario: " usuario

read -s -p "contraseña usuario: " pswd_usu_pg

echo

kubectl exec my-postgresql-0 -n monitoreo -- bash -c "PGPASSWORD='${pswd_pg}' psql -U postgres -c \"
CREATE DATABASE ${db_name};\""

kubectl exec my-postgresql-0 -n monitoreo -- bash -c "PGPASSWORD='${pswd_pg}' psql -U postgres -c \"
CREATE USER ${usuario} WITH PASSWORD '${pswd_usu_pg}';
GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${usuario};\""

kubectl exec my-postgresql-0 -n monitoreo -- bash -c \
"PGPASSWORD='${pswd_pg}' psql -U postgres -d ${db_name} -c \"
GRANT ALL PRIVILEGES ON SCHEMA public TO \\\"${usuario}\\\";
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \\\"${usuario}\\\";
\""

echo -e "${azul}--------------------------------INSTALAR POSTGRESQL EXPORTER--------------------------------${NC}"

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-exporter
  namespace: monitoreo
spec:
  selector:
    matchLabels:
      app: postgres-exporter
  replicas: 1
  template:
    metadata:
      labels:
        app: postgres-exporter
    spec:
      containers:
        - name: postgres-exporter
          image: prometheuscommunity/postgres-exporter:latest
          env:
            - name: DATA_SOURCE_NAME
              value: "postgresql://postgres:${pswd_pg}@my-postgresql:5432/${db_name}?sslmode=disable"
          ports:
            - containerPort: 9187
              name: metrics
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-exporter
  namespace: monitoreo
spec:
  selector:
    app: postgres-exporter
  ports:
    - protocol: TCP
      port: 9187
      targetPort: 9187
  type: NodePort
EOF

echo -e "${azul}-------------------------INSTALAR PROMETHEUS Y CONFIGURACION DE MONITORIZACIÓN DB---------------------------${NC}"

kubectl apply -f - <<EOF
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-data
  namespace: monitoreo
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: local-path
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoreo
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
      - job_name: 'prometheus'
        scrape_interval: 5s
        static_configs:
          - targets: ['localhost:9090']
      - job_name: 'postgres-exporter-namespaceone'
        scrape_interval: 15s
        static_configs:
          - targets: [postgres-exporter.monitoreo.svc.cluster.local:9187]
      - job_name: 'postgres-exporter-namespacetwo'
        scrape_interval: 15s
        static_configs:
          - targets: [postgres-exporter.monitoreo.svc.cluster.local:9187]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoreo
spec:
  selector:
    matchLabels:
      app: prometheus
  replicas: 1
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
        - name: prometheus
          image: prom/prometheus:latest
          args:
            - "--auto-discover-databases"
          ports:
            - containerPort: 9090
          volumeMounts:
            - name: prometheus-data
              mountPath: /etc/prometheus
            - name: prometheus-config
              mountPath: /etc/prometheus/prometheus.yml
              subPath: prometheus.yml
          args:
            - "--config.file=/etc/prometheus/prometheus.yml"
      volumes:
        - name: prometheus-data
          persistentVolumeClaim:
            claimName: prometheus-data
        - name: prometheus-config
          configMap:
            name: prometheus-config
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: monitoreo
spec:
  selector:
    app: prometheus
  ports:
    - protocol: TCP
      port: 9090
      targetPort: 9090
  type: NodePort
EOF

echo -e "${azul} Esperando a que Prometheus-DB esté listo...${NC}"
until kubectl get pods -n monitoreo | grep prometheus | grep -q 'Running'; do
  sleep 5
done

echo -e "${verde} Prometheus-DB está listo.${NC}"

echo -e "${azul}----------------------------------INSTALAR PROMETHEUS CLUSTER---------------------------------------------${NC}"

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/prometheus -n prometheus --create-namespace

echo -e "${azul} Esperando a que Prometheus-cluster esté listo...${NC}"
until kubectl get pods -n prometheus | grep prometheus | grep -q 'Running'; do
  sleep 5
done
echo -e "${verde} Prometheus-cluster está listo.${NC}"

echo -e "${azul}-----------------------------------------INSTALAR GRAFANA------------------------------------------------${NC}"

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

cat <<EOF > values.yaml
loki:
  enabled: true
  persistence:
    enabled: true
    size: 1Gi
    storageClassName: local-path

promtail:
  enabled: true

grafana:
  enabled: true
  persistence:
    enabled: true
    size: 1Gi
    storageClassName: local-path
  sidecar:
    datasources:
      enabled: true
  image:
    tag: 10.2.5
EOF

helm install loki-stack grafana/loki-stack --values values.yaml -n monitoreo

echo -e "${azul} Esperando a que Grafana esté listo...${NC}"
until kubectl get pods -n monitoreo | grep grafana | grep -q 'Running'; do
  sleep 5
done
echo -e "${verde} Grafana está listo.${NC}"

echo -e "${azul}--------------------------------------------AÑADIR ADMINER--------------------------------------------${NC}"
cat <<EOF > adminer.yaml
apiVersion: v1
kind: Service
metadata:
  name: adminer
  namespace: monitoreo
spec:
  type: NodePort
  selector:
    app: adminer
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 8080
      nodePort: 32080

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: adminer
  namespace: monitoreo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: adminer
  template:
    metadata:
      labels:
        app: adminer
    spec:
      containers:
        - name: adminer
          image: adminer:latest
          ports:
            - containerPort: 8080
EOF

kubectl apply -f adminer.yaml

# Mostrar resumen de lo que se va a ejecutar
echo -e "${amarillo}=== COMANDOS QUE SE EJECUTARON EN POSTGRESQL ===${NC}"
echo -e "CREATE DATABASE ${db_name};"
echo -e "CREATE USER ${usuario} WITH PASSWORD '[oculto]';"
echo -e "GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${usuario};"
echo -e "GRANT ALL ON SCHEMA public TO ${usuario};"
echo -e "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${usuario};"

export GRAFANA_PASSWORD=`kubectl -n monitoreo get secret loki-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d`

echo -e "${azul} Usuarios para la base de datos${NC}"

read -p "nombre usuario1: " usuario1

read -s -p "contraseña usuario1: " pswd_usu1_pg

echo

read -p "nombre usuario2: " usuario2

read -s -p "contraseña usuario2: " pswd_usu2_pg

echo

cat > tablas.sql <<EOF
-- Crear base de datos (si se hace con postgres, se hace desde fuera con CREATE DATABASE ...)

-- Crear tablas
CREATE TABLE producto (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(100),
  precio NUMERIC
);

CREATE TABLE clientes (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(100),
  email VARCHAR(100)
);

CREATE TABLE compra (
  id SERIAL PRIMARY KEY,
  cliente_id INT REFERENCES clientes(id),
  fecha DATE
);

CREATE TABLE compra_detalles (
  id SERIAL PRIMARY KEY,
  compra_id INT REFERENCES compra(id),
  producto_id INT REFERENCES producto(id),
  cantidad INT
);

-- Crear usuarios
CREATE USER ${usuario1} WITH PASSWORD '${pswd_usu1_pg}';
CREATE USER ${usuario2} WITH PASSWORD '${pswd_usu2_pg}';

-- Dar permisos WRITE a usu1
GRANT INSERT, UPDATE ON producto, clientes, compra, compra_detalles TO ${usuario1};

-- Dar permisos READ a usu2
GRANT SELECT ON producto, clientes, compra, compra_detalles TO ${usuario2};
EOF

echo -e """contraseña grafana = $GRAFANA_PASSWORD

contraseña postgre = $pswd_pg

Dashboards Grafana:

Prometheus: 18283 - 1860

Loki: 16966

PostgreSQL: 455 - 9628""" > otros

echo -e "${amarillo} revisar archivo --> otros${NC}"
