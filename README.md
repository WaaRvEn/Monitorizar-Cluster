# Monitorizar-Cluster-Kubernetes

![LOGO IES FRANCISCO DE QUEVEDO](./IMG/LogoQuevedo.jpg "LOGO IES FRANCISCO DE QUEVEDO")

## TFG IES QUEVEDO

> En este proyecto haremos un cluster con kubernetes en maquinas virtuales de VMware, 1 **Lubuntu 24.04** como *Nodo Master* y 2 **Ubuntu Server 24.04** como *Nodos Workers*.
>
>> En ellos instalaremos varios servicios pero los que destacan son los de monitorización como **Prometheus** (Para Cluster y Bases de datos), **Grafana** (Para visualizar en dashboards las metricas) y **Loki** (Para hacer una busqueda más a fondo a través de logs). Finalmente la base de datos **PostgreSQL** para comprobar como se comporta el cluster con los datos que añadimos mediante **Adminer** que nos da una interfaz gráfica para hacerlo más sencillo introducir los datos.
>>
> Con este trabajo conseguimos más conocimientos de implantacion de servicios y el entorno en el que se hace y como rinde los servicios en él.
>

![LOGO TFG](./IMG/Logo-TFG.png "LOGO TFG")

> Utilizaremos los [scripts](./SCRIPTS/) para automatizar la instalacion del cluster y los servicios 
>
> `bash script.sh` o `./script.sh`
>

### SERVICIOS

| Monitorizacion | Base de datos |
| :------------: |:-------------:|
| Prometheus     | PostgreSQL    |
| Grafana        | Adminer       |
| Loki           |               |