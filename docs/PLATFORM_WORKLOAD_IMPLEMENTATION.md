# Guía de Implementación: Platform Workload Definition en Microspell

## Resumen

Esta guía detalla cómo extender **microspell** para soportar la especificación **Platform Workload Definition (PWD)** como una API alternativa simplificada.

**Objetivo:** Permitir que los desarrolladores definan workloads usando una sintaxis cloud-agnostic simplificada, mientras microspell traduce internamente a su formato nativo.

---

## Índice

1. [Visión General](#1-visión-general)
2. [Fase 1: Modificar values.yaml](#2-fase-1-modificar-valuesyaml)
3. [Fase 2: Crear Helpers (_platform.tpl)](#3-fase-2-crear-helpers-_platformtpl)
4. [Fase 3: Crear Transformer (platform.yaml)](#4-fase-3-crear-transformer-platformyaml)
5. [Fase 4: Procesar Resources](#5-fase-4-procesar-resources)
6. [Fase 5: Procesar Secrets](#6-fase-5-procesar-secrets)
7. [Fase 6: Procesar Ingress](#7-fase-6-procesar-ingress)
8. [Fase 7: Integrar en base.yaml](#8-fase-7-integrar-en-baseyaml)
9. [Fase 8: Crear Examples](#9-fase-8-crear-examples)
10. [Fase 9: Testing](#10-fase-9-testing)
11. [Fase 10: Documentación](#11-fase-10-documentación)
12. [Mapeo Completo PWD → Microspell](#12-mapeo-completo-pwd--microspell)
13. [Preguntas Frecuentes](#13-preguntas-frecuentes)

---

## 1. Visión General

### ¿Qué es Platform Workload Definition?

Es una especificación YAML simplificada que abstrae:
- Tipos de workload (service, job, cronjob)
- Recursos cloud (object-storage, relational-db, cache, etc.)
- Configuración de scaling, ingress, secrets

### ¿Por qué extender Microspell?

Microspell ya tiene:
- Integración con Summon (workloads)
- Integración con Vault (secrets)
- Integración con Istio (networking)
- Integración con PostgreSQL (dataStore)
- Sistema de glyphs (extensibilidad)

En lugar de crear algo nuevo, aprovechamos esta infraestructura existente.

### Arquitectura de la Solución

```
┌─────────────────────────────────────────────────────────┐
│                    Usuario                               │
│                                                          │
│   platform:                    O     name: my-service   │
│     enabled: true                    workload:          │
│     type: service                      type: deployment │
│     ...                               ...               │
│                                                          │
│   (Formato PWD)                      (Formato Microspell)│
└──────────────┬──────────────────────────────┬───────────┘
               │                              │
               │   Si platform.enabled        │ Si NO platform.enabled
               ▼                              ▼
┌──────────────────────────┐    ┌──────────────────────────┐
│   templates/platform.yaml │    │   templates/base.yaml    │
│   (Transformer)           │    │   (Flujo normal)         │
│                           │    │                          │
│   - Valida PWD            │    │                          │
│   - Transforma a nativo   │    │                          │
│   - Genera recursos       │    │                          │
└───────────┬───────────────┘    └──────────┬───────────────┘
            │                               │
            └───────────────┬───────────────┘
                            ▼
              ┌──────────────────────────┐
              │   Glyphs de Summon       │
              │   - summon.workload.*    │
              │   - summon.service       │
              │   - summon.autoscaling   │
              │   - vault.secret         │
              │   - istio.virtualService │
              └──────────────────────────┘
                            │
                            ▼
              ┌──────────────────────────┐
              │   Recursos Kubernetes    │
              │   - Deployment/Job/Cron  │
              │   - Service              │
              │   - HPA                  │
              │   - VirtualService       │
              │   - ExternalSecret       │
              └──────────────────────────┘
```

---

## 2. Fase 1: Modificar values.yaml

### Objetivo
Agregar la sección `platform:` al archivo `values.yaml` de microspell.

### Archivo a modificar
`charts/trinkets/microspell/values.yaml`

### Ubicación en el archivo
Al inicio del archivo, después de los comentarios iniciales y antes de la sección `name:`.

### Código a agregar

```yaml
# =============================================================================
# PLATFORM WORKLOAD DEFINITION (PWD) MODE
# =============================================================================
# Cuando platform.enabled es true, microspell usa la API simplificada de PWD
# en lugar de la API nativa de microspell.
#
# Documentación: docs/PLATFORM_WORKLOAD.md
# =============================================================================

platform:
  # Habilitar modo Platform Workload Definition
  enabled: false

  # Versión de la especificación PWD
  version: "1.0"

  # Identificación del workload (requeridos si enabled: true)
  name: ""
  namespace: ""

  # Tipo de workload: service | job | cronjob
  type: service

  # Imagen del contenedor
  image:
    repository: ""
    tag: "latest"

  # ---------------------------------------------------------------------------
  # POLÍTICAS DE RECURSOS
  # ---------------------------------------------------------------------------
  # Define qué recursos cloud necesita este workload y con qué permisos
  #
  # Tipos soportados:
  #   - object-storage    (S3, Azure Blob, GCS)
  #   - secrets-vault     (HashiCorp Vault)
  #   - relational-db     (PostgreSQL, MySQL, RDS)
  #   - document-db       (MongoDB, DocumentDB)
  #   - key-value-store   (DynamoDB, Redis)
  #   - message-queue     (SQS, RabbitMQ)
  #   - event-stream      (Kinesis, Kafka)
  #   - cache             (Redis, Memcached)
  #
  # Niveles de acceso:
  #   - read              Solo lectura
  #   - write             Solo escritura
  #   - read-write        Lectura y escritura
  #   - publish           Publicar mensajes (queues/streams)
  #   - consume           Consumir mensajes (queues/streams)
  #   - full              Acceso completo (incluye admin)
  # ---------------------------------------------------------------------------
  policies:
    resources: []
    # Ejemplo:
    # - type: object-storage
    #   name: customer-uploads
    #   access: read-write
    #
    # - type: secrets-vault
    #   name: api-credentials
    #   access: read
    #
    # - type: relational-db
    #   name: orders-db
    #   access: read-write

  # ---------------------------------------------------------------------------
  # INYECCIÓN DE SECRETS
  # ---------------------------------------------------------------------------
  # Secrets que se inyectarán como variables de entorno
  # El secret debe existir en policies.resources con type: secrets-vault
  # ---------------------------------------------------------------------------
  secrets: []
  # Ejemplo:
  # - key: database-credentials      # Nombre del secret
  #   env: DB_CONNECTION_STRING      # Nombre de la env var (opcional)
  #                                  # Default: DATABASE_CREDENTIALS

  # ---------------------------------------------------------------------------
  # ESCALABILIDAD (solo para type: service)
  # ---------------------------------------------------------------------------
  scalability:
    # Número de instancias
    instances:
      min: 1        # Mínimo de réplicas
      max: 4        # Máximo de réplicas (para autoscaling)

    # Recursos por instancia
    resources:
      cpu: 0.5      # Cores (0.25 - 2)
      memory: 1     # GB (0.5 - 8)

    # Configuración de auto-scaling
    scaling:
      metric: cpu       # cpu | memory | requests
      threshold: 70     # Porcentaje o valor absoluto

  # ---------------------------------------------------------------------------
  # INGRESS (solo para type: service)
  # ---------------------------------------------------------------------------
  ingress:
    enabled: false
    protocol: https     # https | grpc | websocket | tcp
    port: 443
    exposure: internal  # internal | public

    # Rate limiting (requerido si exposure: public)
    rate-limiting:
      requests-per-second: 100
      burst: 200

    # Health checks
    health:
      path: /health
      interval: 30          # segundos
      timeout: 5            # segundos
      healthy-threshold: 2
      unhealthy-threshold: 3

  # ---------------------------------------------------------------------------
  # CONFIGURACIÓN DE JOB (solo para type: job)
  # ---------------------------------------------------------------------------
  job:
    retries: 3              # Reintentos en caso de fallo
    timeout: 3600           # Timeout en segundos (1 hora)
    cleanup: on-success     # always | on-success | never
    retention: 72h          # Tiempo de retención (30m, 24h, 7d)
    parallelism: 1          # Instancias en paralelo
    completions: 1          # Completaciones requeridas

  # ---------------------------------------------------------------------------
  # CONFIGURACIÓN DE CRONJOB (solo para type: cronjob)
  # ---------------------------------------------------------------------------
  cronjob:
    schedule: ""            # Expresión cron (5 campos) - REQUERIDO
    concurrency: forbid     # allow | forbid | replace
    retries: 3
    timeout: 3600
    history-limit: 3
    starting-deadline: 300  # segundos

  # ---------------------------------------------------------------------------
  # VARIABLES DE ENTORNO
  # ---------------------------------------------------------------------------
  environment: []
  # Ejemplo:
  # - name: LOG_LEVEL
  #   value: info
  # - name: FEATURE_FLAGS
  #   value: "new-checkout,beta-api"

  # ---------------------------------------------------------------------------
  # METADATA
  # ---------------------------------------------------------------------------
  labels: {}
  # Ejemplo:
  #   team: payments
  #   cost-center: cc-1234

  annotations: {}
  # Ejemplo:
  #   owner: payments-team@company.com
```

### Notas importantes

1. **Ubicación**: Esta sección debe ir ANTES de la sección `name:` existente
2. **Default**: `platform.enabled: false` para mantener backward compatibility
3. **Documentación inline**: Los comentarios explican cada campo para los usuarios

---

## 3. Fase 2: Crear Helpers (_platform.tpl)

### Objetivo
Crear funciones helper reutilizables para el transformer.

### Archivo a crear
`charts/trinkets/microspell/templates/_platform.tpl`

### Código completo

```yaml
{{/*
=============================================================================
PLATFORM WORKLOAD DEFINITION - HELPERS
=============================================================================
Funciones helper para transformar PWD a formato microspell nativo.
=============================================================================
*/}}

{{/*
-----------------------------------------------------------------------------
platform.isEnabled
-----------------------------------------------------------------------------
Retorna "true" si el modo platform está habilitado.

Uso:
  {{- if include "platform.isEnabled" . }}
  ...
  {{- end }}
-----------------------------------------------------------------------------
*/}}
{{- define "platform.isEnabled" -}}
{{- if and .Values.platform .Values.platform.enabled -}}
true
{{- end -}}
{{- end -}}

{{/*
-----------------------------------------------------------------------------
platform.cpu.toMillicores
-----------------------------------------------------------------------------
Convierte CPU en formato decimal a millicores.

Entrada: 0.5, 1, 2
Salida:  500m, 1000m, 2000m

Uso:
  {{ include "platform.cpu.toMillicores" 0.5 }}
  # Output: 500m
-----------------------------------------------------------------------------
*/}}
{{- define "platform.cpu.toMillicores" -}}
{{- $cpu := . -}}
{{- if typeIs "float64" $cpu -}}
{{- printf "%dm" (int (mulf $cpu 1000)) -}}
{{- else if typeIs "int64" $cpu -}}
{{- printf "%dm" (int (mul $cpu 1000)) -}}
{{- else -}}
{{- $cpu -}}
{{- end -}}
{{- end -}}

{{/*
-----------------------------------------------------------------------------
platform.memory.toGi
-----------------------------------------------------------------------------
Convierte memoria en GB a formato Kubernetes (Gi).

Entrada: 1, 2, 8
Salida:  1Gi, 2Gi, 8Gi

Uso:
  {{ include "platform.memory.toGi" 2 }}
  # Output: 2Gi
-----------------------------------------------------------------------------
*/}}
{{- define "platform.memory.toGi" -}}
{{- $mem := . -}}
{{- printf "%dGi" (int $mem) -}}
{{- end -}}

{{/*
-----------------------------------------------------------------------------
platform.retention.toSeconds
-----------------------------------------------------------------------------
Convierte formato de retención (30m, 24h, 7d) a segundos.

Entrada: 30m, 24h, 72h, 7d
Salida:  1800, 86400, 259200, 604800

Uso:
  {{ include "platform.retention.toSeconds" "72h" }}
  # Output: 259200
-----------------------------------------------------------------------------
*/}}
{{- define "platform.retention.toSeconds" -}}
{{- $ret := . -}}
{{- if hasSuffix "m" $ret -}}
{{- $val := trimSuffix "m" $ret | int -}}
{{- mul $val 60 -}}
{{- else if hasSuffix "h" $ret -}}
{{- $val := trimSuffix "h" $ret | int -}}
{{- mul $val 3600 -}}
{{- else if hasSuffix "d" $ret -}}
{{- $val := trimSuffix "d" $ret | int -}}
{{- mul $val 86400 -}}
{{- else -}}
{{- $ret | int -}}
{{- end -}}
{{- end -}}

{{/*
-----------------------------------------------------------------------------
platform.env.toDict
-----------------------------------------------------------------------------
Convierte array de environment a dict para Summon.

Entrada: [{name: LOG_LEVEL, value: info}, {name: PORT, value: "8080"}]
Salida:  {LOG_LEVEL: info, PORT: "8080"}

Uso:
  {{- $envs := include "platform.env.toDict" .Values.platform.environment | fromYaml }}
-----------------------------------------------------------------------------
*/}}
{{- define "platform.env.toDict" -}}
{{- $envArray := . -}}
{{- $result := dict -}}
{{- range $env := $envArray -}}
{{- $_ := set $result $env.name $env.value -}}
{{- end -}}
{{- $result | toYaml -}}
{{- end -}}

{{/*
-----------------------------------------------------------------------------
platform.key.toEnvName
-----------------------------------------------------------------------------
Convierte un key en formato kebab-case a UPPER_SNAKE_CASE.

Entrada: database-credentials, api-key
Salida:  DATABASE_CREDENTIALS, API_KEY

Uso:
  {{ include "platform.key.toEnvName" "database-credentials" }}
  # Output: DATABASE_CREDENTIALS
-----------------------------------------------------------------------------
*/}}
{{- define "platform.key.toEnvName" -}}
{{- . | upper | replace "-" "_" -}}
{{- end -}}

{{/*
-----------------------------------------------------------------------------
platform.type.toWorkloadType
-----------------------------------------------------------------------------
Convierte tipo PWD a tipo de workload de Summon.

Entrada: service, job, cronjob
Salida:  deployment, job, cronjob

Uso:
  {{ include "platform.type.toWorkloadType" "service" }}
  # Output: deployment
-----------------------------------------------------------------------------
*/}}
{{- define "platform.type.toWorkloadType" -}}
{{- $type := . -}}
{{- if eq $type "service" -}}
deployment
{{- else -}}
{{- $type -}}
{{- end -}}
{{- end -}}

{{/*
-----------------------------------------------------------------------------
platform.exposure.toSelector
-----------------------------------------------------------------------------
Convierte exposure level a selector de gateway.

Entrada: public, internal
Salida:  {access: external}, {access: internal}

Uso:
  {{- $selector := include "platform.exposure.toSelector" "public" | fromYaml }}
-----------------------------------------------------------------------------
*/}}
{{- define "platform.exposure.toSelector" -}}
{{- $exposure := . -}}
{{- if eq $exposure "public" -}}
access: external
{{- else -}}
access: internal
{{- end -}}
{{- end -}}

{{/*
-----------------------------------------------------------------------------
platform.access.toVaultCapabilities
-----------------------------------------------------------------------------
Convierte access level de PWD a capabilities de Vault.

Entrada: read, write, read-write, full
Salida:  ["read", "list"], ["create",...], etc.

Uso:
  {{- $caps := include "platform.access.toVaultCapabilities" "read-write" }}
-----------------------------------------------------------------------------
*/}}
{{- define "platform.access.toVaultCapabilities" -}}
{{- $level := . -}}
{{- if eq $level "read" -}}
["read", "list"]
{{- else if eq $level "write" -}}
["create", "update", "delete"]
{{- else if eq $level "read-write" -}}
["read", "list", "create", "update", "delete"]
{{- else if eq $level "full" -}}
["read", "list", "create", "update", "delete", "sudo"]
{{- else -}}
["read"]
{{- end -}}
{{- end -}}

{{/*
-----------------------------------------------------------------------------
platform.access.toS3Actions
-----------------------------------------------------------------------------
Convierte access level de PWD a acciones S3/IAM.

Entrada: read, write, read-write, full
Salida:  ["s3:GetObject",...], etc.

Uso:
  {{- $actions := include "platform.access.toS3Actions" "read-write" | fromYamlArray }}
-----------------------------------------------------------------------------
*/}}
{{- define "platform.access.toS3Actions" -}}
{{- $level := . -}}
{{- if eq $level "read" -}}
- s3:GetObject
- s3:ListBucket
{{- else if eq $level "write" -}}
- s3:PutObject
- s3:DeleteObject
{{- else if eq $level "read-write" -}}
- s3:GetObject
- s3:ListBucket
- s3:PutObject
- s3:DeleteObject
{{- else if eq $level "full" -}}
- s3:*
{{- end -}}
{{- end -}}

{{/*
-----------------------------------------------------------------------------
platform.access.toDbRole
-----------------------------------------------------------------------------
Convierte access level de PWD a rol de base de datos.

Entrada: read, write, read-write, full
Salida:  readonly, readwrite, admin

Uso:
  {{ include "platform.access.toDbRole" "read-write" }}
  # Output: readwrite
-----------------------------------------------------------------------------
*/}}
{{- define "platform.access.toDbRole" -}}
{{- $level := . -}}
{{- if eq $level "read" -}}
readonly
{{- else if eq $level "write" -}}
readwrite
{{- else if eq $level "read-write" -}}
readwrite
{{- else if eq $level "full" -}}
admin
{{- else -}}
readonly
{{- end -}}
{{- end -}}

{{/*
-----------------------------------------------------------------------------
platform.cleanup.toTTL
-----------------------------------------------------------------------------
Convierte política de cleanup a ttlSecondsAfterFinished.

Entrada: always, on-success, never
Salida:  0, 100, -1 (donde -1 significa no configurar)

Uso:
  {{- $ttl := include "platform.cleanup.toTTL" "on-success" }}
-----------------------------------------------------------------------------
*/}}
{{- define "platform.cleanup.toTTL" -}}
{{- $cleanup := . -}}
{{- if eq $cleanup "always" -}}
0
{{- else if eq $cleanup "on-success" -}}
100
{{- else -}}
-1
{{- end -}}
{{- end -}}
```

### Explicación de cada helper

| Helper | Entrada | Salida | Propósito |
|--------|---------|--------|-----------|
| `platform.isEnabled` | context | "true" o "" | Detectar si PWD está activo |
| `platform.cpu.toMillicores` | 0.5 | "500m" | Convertir CPU a formato K8s |
| `platform.memory.toGi` | 2 | "2Gi" | Convertir memoria a formato K8s |
| `platform.retention.toSeconds` | "72h" | 259200 | Parsear tiempo de retención |
| `platform.env.toDict` | array | dict | Convertir env vars a formato Summon |
| `platform.key.toEnvName` | "api-key" | "API_KEY" | Convertir key a env name |
| `platform.type.toWorkloadType` | "service" | "deployment" | Mapear tipo PWD a Summon |
| `platform.exposure.toSelector` | "public" | selector | Generar selector de gateway |
| `platform.access.toVaultCapabilities` | "read" | capabilities | Mapear acceso a Vault |
| `platform.access.toS3Actions` | "read" | actions | Mapear acceso a S3 |
| `platform.access.toDbRole` | "read" | "readonly" | Mapear acceso a DB role |
| `platform.cleanup.toTTL` | "always" | 0 | Mapear cleanup a TTL |

---

## 4. Fase 3: Crear Transformer (platform.yaml)

### Objetivo
Crear el template principal que transforma PWD a formato microspell nativo.

### Archivo a crear
`charts/trinkets/microspell/templates/platform.yaml`

### Código completo

```yaml
{{/*
=============================================================================
PLATFORM WORKLOAD DEFINITION - TRANSFORMER
=============================================================================
Este template se ejecuta cuando platform.enabled es true.
Transforma la configuración PWD a formato microspell nativo y genera
los recursos Kubernetes correspondientes.
=============================================================================
*/}}

{{- if include "platform.isEnabled" . }}
{{- $root := . }}
{{- $p := .Values.platform }}

{{/* ===========================================================================
     VALIDACIONES
     =========================================================================== */}}

{{/* Validar que type es válido */}}
{{- if not (has $p.type (list "service" "job" "cronjob")) }}
{{- fail (printf "platform.type debe ser uno de: service, job, cronjob. Recibido: %s" $p.type) }}
{{- end }}

{{/* Validar que image.repository existe */}}
{{- if not $p.image.repository }}
{{- fail "platform.image.repository es requerido cuando platform.enabled es true" }}
{{- end }}

{{/* Validar que cronjob tiene schedule */}}
{{- if and (eq $p.type "cronjob") (not $p.cronjob.schedule) }}
{{- fail "platform.cronjob.schedule es requerido cuando platform.type es cronjob" }}
{{- end }}

{{/* ===========================================================================
     TRANSFORMACIÓN DE VALORES
     =========================================================================== */}}

{{/* Determinar tipo de workload */}}
{{- $workloadType := include "platform.type.toWorkloadType" $p.type }}

{{/* Construir resources de Kubernetes */}}
{{- $k8sResources := dict }}
{{- if $p.scalability.resources }}
  {{- if $p.scalability.resources.cpu }}
    {{- $cpuValue := include "platform.cpu.toMillicores" $p.scalability.resources.cpu }}
    {{- $_ := set $k8sResources "requests" (dict "cpu" $cpuValue) }}
    {{- $_ := set $k8sResources "limits" (dict "cpu" $cpuValue) }}
  {{- end }}
  {{- if $p.scalability.resources.memory }}
    {{- $memValue := include "platform.memory.toGi" $p.scalability.resources.memory }}
    {{- if $k8sResources.requests }}
      {{- $_ := set $k8sResources.requests "memory" $memValue }}
      {{- $_ := set $k8sResources.limits "memory" $memValue }}
    {{- else }}
      {{- $_ := set $k8sResources "requests" (dict "memory" $memValue) }}
      {{- $_ := set $k8sResources "limits" (dict "memory" $memValue) }}
    {{- end }}
  {{- end }}
{{- end }}

{{/* Construir configuración de workload */}}
{{- $workloadConfig := dict "enabled" true "type" $workloadType }}

{{/* Configurar replicas desde scalability.instances.min */}}
{{- if and $p.scalability $p.scalability.instances $p.scalability.instances.min }}
  {{- $_ := set $workloadConfig "replicas" $p.scalability.instances.min }}
{{- end }}

{{/* Configuración específica de Job */}}
{{- if eq $p.type "job" }}
  {{- if $p.job.retries }}
    {{- $_ := set $workloadConfig "backoffLimit" $p.job.retries }}
  {{- end }}
  {{- if $p.job.timeout }}
    {{- $_ := set $workloadConfig "activeDeadlineSeconds" $p.job.timeout }}
  {{- end }}
  {{- if $p.job.parallelism }}
    {{- $_ := set $workloadConfig "parallelism" $p.job.parallelism }}
  {{- end }}
  {{- if $p.job.completions }}
    {{- $_ := set $workloadConfig "completions" $p.job.completions }}
  {{- end }}
  {{- if $p.job.cleanup }}
    {{- $ttl := include "platform.cleanup.toTTL" $p.job.cleanup }}
    {{- if ne $ttl "-1" }}
      {{- $_ := set $workloadConfig "ttlSecondsAfterFinished" ($ttl | int) }}
    {{- end }}
  {{- end }}
{{- end }}

{{/* Configuración específica de CronJob */}}
{{- if eq $p.type "cronjob" }}
  {{- $_ := set $workloadConfig "schedule" $p.cronjob.schedule }}
  {{- if $p.cronjob.concurrency }}
    {{- $concurrencyMap := dict "allow" "Allow" "forbid" "Forbid" "replace" "Replace" }}
    {{- $_ := set $workloadConfig "concurrencyPolicy" (get $concurrencyMap $p.cronjob.concurrency) }}
  {{- end }}
  {{- if $p.cronjob.history-limit }}
    {{- $_ := set $workloadConfig "successfulJobsHistoryLimit" (index $p.cronjob "history-limit") }}
    {{- $_ := set $workloadConfig "failedJobsHistoryLimit" 1 }}
  {{- end }}
  {{- if $p.cronjob.starting-deadline }}
    {{- $_ := set $workloadConfig "startingDeadlineSeconds" (index $p.cronjob "starting-deadline") }}
  {{- end }}
  {{/* Heredar config de job para el template del cronjob */}}
  {{- if $p.cronjob.retries }}
    {{- $_ := set $workloadConfig "backoffLimit" $p.cronjob.retries }}
  {{- end }}
  {{- if $p.cronjob.timeout }}
    {{- $_ := set $workloadConfig "activeDeadlineSeconds" $p.cronjob.timeout }}
  {{- end }}
{{- end }}

{{/* Construir configuración de autoscaling */}}
{{- $autoscalingConfig := dict "enabled" false }}
{{- if and (eq $p.type "service") $p.scalability $p.scalability.instances }}
  {{- if and $p.scalability.instances.min $p.scalability.instances.max }}
    {{- if gt $p.scalability.instances.max $p.scalability.instances.min }}
      {{- $_ := set $autoscalingConfig "enabled" true }}
      {{- $_ := set $autoscalingConfig "minReplicas" $p.scalability.instances.min }}
      {{- $_ := set $autoscalingConfig "maxReplicas" $p.scalability.instances.max }}
      {{- if $p.scalability.scaling }}
        {{- if eq $p.scalability.scaling.metric "cpu" }}
          {{- $_ := set $autoscalingConfig "targetCPUUtilizationPercentage" $p.scalability.scaling.threshold }}
        {{- else if eq $p.scalability.scaling.metric "memory" }}
          {{- $_ := set $autoscalingConfig "targetMemoryUtilizationPercentage" $p.scalability.scaling.threshold }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}

{{/* Construir configuración de service */}}
{{- $serviceConfig := dict "enabled" false }}
{{- if and (eq $p.type "service") $p.ingress $p.ingress.enabled }}
  {{- $_ := set $serviceConfig "enabled" true }}
  {{- $_ := set $serviceConfig "type" "ClusterIP" }}
  {{- $_ := set $serviceConfig "ports" (list (dict "port" $p.ingress.port "name" "http")) }}
  {{- if eq $p.ingress.exposure "public" }}
    {{- $_ := set $serviceConfig "external" true }}
  {{- end }}
{{- end }}

{{/* Construir probes desde health checks */}}
{{- $probesConfig := dict }}
{{- if and $p.ingress $p.ingress.enabled $p.ingress.health }}
  {{- $healthPath := default "/health" $p.ingress.health.path }}
  {{- $healthPort := $p.ingress.port }}
  {{- $probesConfig = dict
      "liveness" (dict
        "type" "httpGet"
        "path" $healthPath
        "port" $healthPort
        "periodSeconds" (default 30 $p.ingress.health.interval)
        "timeoutSeconds" (default 5 $p.ingress.health.timeout)
        "successThreshold" (default 1 (index $p.ingress.health "healthy-threshold"))
        "failureThreshold" (default 3 (index $p.ingress.health "unhealthy-threshold"))
      )
      "readiness" (dict
        "type" "httpGet"
        "path" $healthPath
        "port" $healthPort
        "periodSeconds" (default 10 $p.ingress.health.interval)
        "timeoutSeconds" (default 5 $p.ingress.health.timeout)
      )
  }}
{{- end }}

{{/* Convertir environment array a dict */}}
{{- $envsDict := dict }}
{{- if $p.environment }}
  {{- range $env := $p.environment }}
    {{- $_ := set $envsDict $env.name $env.value }}
  {{- end }}
{{- end }}

{{/* ===========================================================================
     GENERAR RECURSOS
     =========================================================================== */}}

{{/*
Nota: En este punto, hemos transformado todos los valores de PWD a formato
microspell nativo. Ahora necesitamos:
1. Inyectar estos valores en el contexto
2. Llamar a los templates de Summon

La forma de hacer esto depende de cómo queramos integrarnos con base.yaml.
Ver Fase 7 para la integración completa.
*/}}

{{- end }}
```

### Explicación del flujo

1. **Validaciones**: Primero validamos que los campos requeridos existan y tengan valores válidos
2. **Transformación de workload.type**: `service` → `deployment`, otros pasan directo
3. **Transformación de resources**: CPU y memoria se convierten a formato K8s
4. **Configuración de job/cronjob**: Se mapean retries, timeout, cleanup, etc.
5. **Autoscaling**: Se configura si hay diferencia entre min y max instances
6. **Service**: Se habilita si ingress está configurado
7. **Probes**: Se generan desde la configuración de health checks
8. **Environment**: Se convierte de array a dict

---

## 5. Fase 4: Procesar Resources

### Objetivo
Procesar `platform.policies.resources` y generar los recursos correspondientes.

### Dónde agregar
En `templates/platform.yaml`, después de las transformaciones básicas.

### Código a agregar

```yaml
{{/* ===========================================================================
     PROCESAR POLICIES.RESOURCES
     =========================================================================== */}}

{{- if $p.policies }}
{{- if $p.policies.resources }}
{{- range $resource := $p.policies.resources }}

{{/* ----- SECRETS-VAULT ----- */}}
{{- if eq $resource.type "secrets-vault" }}
{{/*
  Buscar configuración de Vault en lexicon via runicIndexer.
  Generar entrada en secrets de microspell.
*/}}
{{- $vaultSelector := default (dict) $resource.selector }}
{{- $vaultConfig := get (include "runicIndexer.runicIndexer" (list $root.Values.lexicon $vaultSelector "vault" $root.Values.chapter.name) | fromJson) "results" }}
{{- if $vaultConfig }}
{{- $secretConfig := dict
    "name" $resource.name
    "location" "vault"
    "path" (default "chapter" $resource.path)
    "format" "env"
}}
{{- if $resource.keys }}
  {{- $_ := set $secretConfig "keys" $resource.keys }}
{{- end }}
{{/* Este secret se agregará a la lista de secrets de microspell */}}
{{- end }}
{{- end }}

{{/* ----- OBJECT-STORAGE ----- */}}
{{- if eq $resource.type "object-storage" }}
{{/*
  Buscar configuración de S3 en lexicon.
  Generar glyph s3.bucket con los permisos apropiados.
*/}}
{{- $s3Selector := default (dict) $resource.selector }}
{{- $s3Config := get (include "runicIndexer.runicIndexer" (list $root.Values.lexicon $s3Selector "s3-provider" $root.Values.chapter.name) | fromJson) "results" }}
{{- if $s3Config }}
{{- $bucketConfig := dict
    "name" $resource.name
    "type" "bucket"
}}
{{- $actions := include "platform.access.toS3Actions" $resource.access }}
{{- $_ := set $bucketConfig "permissions" $actions }}
{{/* Llamar a glyph s3 */}}
{{- end }}
{{- end }}

{{/* ----- RELATIONAL-DB ----- */}}
{{- if eq $resource.type "relational-db" }}
{{/*
  Buscar configuración de DB en lexicon.
  Si es CNPG: configurar dataStore.psql de microspell.
  Si es AWS RDS: usar glyph aws.
*/}}
{{- $dbSelector := default (dict) $resource.selector }}
{{- $dbConfig := get (include "runicIndexer.runicIndexer" (list $root.Values.lexicon $dbSelector "rdb-provider" $root.Values.chapter.name) | fromJson) "results" }}
{{- if $dbConfig }}
{{- $dbRole := include "platform.access.toDbRole" $resource.access }}
{{/*
  Aquí configuramos dataStore.psql si es CNPG:

  dataStore:
    psql:
      enabled: true
      selector: <dbSelector>
      credentials:
        dynamic:
          role: <dbRole>
*/}}
{{- end }}
{{- end }}

{{/* ----- CACHE ----- */}}
{{- if eq $resource.type "cache" }}
{{- $cacheSelector := default (dict) $resource.selector }}
{{- $cacheConfig := get (include "runicIndexer.runicIndexer" (list $root.Values.lexicon $cacheSelector "cache-provider" $root.Values.chapter.name) | fromJson) "results" }}
{{/* Generar configuración de cache según provider */}}
{{- end }}

{{/* ----- MESSAGE-QUEUE ----- */}}
{{- if eq $resource.type "message-queue" }}
{{- $mqSelector := default (dict) $resource.selector }}
{{- $mqConfig := get (include "runicIndexer.runicIndexer" (list $root.Values.lexicon $mqSelector "mq-provider" $root.Values.chapter.name) | fromJson) "results" }}
{{/* Generar configuración de queue según provider */}}
{{- end }}

{{/* ----- EVENT-STREAM ----- */}}
{{- if eq $resource.type "event-stream" }}
{{- $streamSelector := default (dict) $resource.selector }}
{{- $streamConfig := get (include "runicIndexer.runicIndexer" (list $root.Values.lexicon $streamSelector "stream-provider" $root.Values.chapter.name) | fromJson) "results" }}
{{/* Generar configuración de stream según provider */}}
{{- end }}

{{/* ----- KEY-VALUE-STORE ----- */}}
{{- if eq $resource.type "key-value-store" }}
{{- $kvSelector := default (dict) $resource.selector }}
{{- $kvConfig := get (include "runicIndexer.runicIndexer" (list $root.Values.lexicon $kvSelector "kv-provider" $root.Values.chapter.name) | fromJson) "results" }}
{{/* Generar configuración de KV store según provider */}}
{{- end }}

{{/* ----- DOCUMENT-DB ----- */}}
{{- if eq $resource.type "document-db" }}
{{- $docSelector := default (dict) $resource.selector }}
{{- $docConfig := get (include "runicIndexer.runicIndexer" (list $root.Values.lexicon $docSelector "docdb-provider" $root.Values.chapter.name) | fromJson) "results" }}
{{/* Generar configuración de document DB según provider */}}
{{- end }}

{{- end }}{{/* range resources */}}
{{- end }}{{/* if resources */}}
{{- end }}{{/* if policies */}}
```

### Mapeo de tipos de recursos a providers

| PWD Resource Type | Lexicon Type | Glyph/Config destino |
|-------------------|--------------|---------------------|
| `object-storage` | `s3-provider` | glyph `s3.bucket` |
| `secrets-vault` | `vault` | `secrets:` de microspell |
| `relational-db` | `rdb-provider` | `dataStore.psql` o glyph `aws` |
| `cache` | `cache-provider` | Según provider (redis, etc.) |
| `message-queue` | `mq-provider` | Según provider (sqs, rabbitmq) |
| `event-stream` | `stream-provider` | Según provider (kinesis, kafka) |
| `key-value-store` | `kv-provider` | Según provider (dynamodb, etc.) |
| `document-db` | `docdb-provider` | Según provider (mongodb, etc.) |

---

## 6. Fase 5: Procesar Secrets

### Objetivo
Procesar `platform.secrets` para inyectar secrets como variables de entorno.

### Código a agregar en platform.yaml

```yaml
{{/* ===========================================================================
     PROCESAR SECRETS INJECTION
     =========================================================================== */}}

{{- $secretsToInject := dict }}

{{- if $p.secrets }}
{{- range $secret := $p.secrets }}

{{/* Buscar el resource de tipo secrets-vault con este key */}}
{{- $foundResource := dict }}
{{- if $p.policies }}
{{- if $p.policies.resources }}
{{- range $resource := $p.policies.resources }}
  {{- if and (eq $resource.type "secrets-vault") (eq $resource.name $secret.key) }}
    {{- $foundResource = $resource }}
  {{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/* Determinar nombre de la variable de entorno */}}
{{- $envName := "" }}
{{- if $secret.env }}
  {{- $envName = $secret.env }}
{{- else }}
  {{- $envName = include "platform.key.toEnvName" $secret.key }}
{{- end }}

{{/*
  Generar configuración de secret para microspell.

  El formato de microspell es:
  secrets:
    <secret-name>:
      location: vault
      path: chapter
      format: env
      keys: [key1, key2]
*/}}
{{- $secretConfig := dict
    "location" "vault"
    "path" "chapter"
    "format" "env"
}}

{{- if $foundResource }}
  {{- if $foundResource.keys }}
    {{- $_ := set $secretConfig "keys" $foundResource.keys }}
  {{- end }}
{{- end }}

{{- $_ := set $secretsToInject $secret.key $secretConfig }}

{{- end }}{{/* range secrets */}}
{{- end }}{{/* if secrets */}}

{{/*
  $secretsToInject ahora contiene todos los secrets configurados
  en formato microspell nativo:

  {
    "database-credentials": {
      "location": "vault",
      "path": "chapter",
      "format": "env",
      "keys": ["username", "password"]
    },
    "api-key": {
      "location": "vault",
      "path": "chapter",
      "format": "env"
    }
  }
*/}}
```

### Ejemplo de transformación

**Entrada (PWD):**
```yaml
platform:
  policies:
    resources:
      - type: secrets-vault
        name: database-credentials
        access: read
        keys: [username, password]
  secrets:
    - key: database-credentials
      env: DB_CREDS
```

**Salida (Microspell nativo):**
```yaml
secrets:
  database-credentials:
    location: vault
    path: chapter
    format: env
    keys: [username, password]
```

---

## 7. Fase 6: Procesar Ingress

### Objetivo
Procesar `platform.ingress` para configurar el service y VirtualService de Istio.

### Código a agregar en platform.yaml

```yaml
{{/* ===========================================================================
     PROCESAR INGRESS
     =========================================================================== */}}

{{- $istioConfig := dict }}

{{- if and (eq $p.type "service") $p.ingress $p.ingress.enabled }}

{{/* Configurar service de microspell */}}
{{- $serviceConfig := dict
    "enabled" true
    "type" "ClusterIP"
    "ports" (list (dict "port" $p.ingress.port "name" "http"))
}}

{{/* Determinar si es externo */}}
{{- if eq $p.ingress.exposure "public" }}
  {{- $_ := set $serviceConfig "external" true }}

  {{/* Configurar rate limiting si está definido */}}
  {{- if index $p.ingress "rate-limiting" }}
    {{- $rateLimiting := index $p.ingress "rate-limiting" }}
    {{/*
      El rate limiting se configura via EnvoyFilter o
      configuración de Istio. Aquí preparamos los valores.
    */}}
  {{- end }}
{{- else }}
  {{- $_ := set $serviceConfig "external" false }}
{{- end }}

{{/* Obtener selector para el gateway */}}
{{- $gatewaySelector := include "platform.exposure.toSelector" $p.ingress.exposure | fromYaml }}

{{/* Configurar VirtualService via glyph istio */}}
{{- $vsConfig := dict
    "type" "virtualService"
    "enabled" true
    "selector" $gatewaySelector
}}

{{/* Configurar prefix basado en el nombre del servicio */}}
{{- $serviceName := default $p.name $root.Values.name }}
{{- $_ := set $vsConfig "prefix" (printf "/%s" $serviceName) }}

{{/* Agregar hosts si es público */}}
{{- if eq $p.ingress.exposure "public" }}
  {{/* Los hosts se determinan desde el lexicon o configuración */}}
{{- end }}

{{- $istioConfig = $vsConfig }}

{{- end }}{{/* if ingress enabled */}}

{{/*
  $serviceConfig contiene la configuración del service de microspell
  $istioConfig contiene la configuración para el glyph istio.virtualService
*/}}
```

### Mapeo de exposure a configuración

| Exposure | service.external | Gateway Selector |
|----------|-----------------|------------------|
| `public` | `true` | `access: external` |
| `internal` | `false` | `access: internal` |

---

## 8. Fase 7: Integrar en base.yaml

### Objetivo
Modificar `base.yaml` para detectar el modo platform y aplicar las transformaciones.

### Archivo a modificar
`charts/trinkets/microspell/templates/base.yaml`

### Cambios a realizar

**Al inicio del archivo, agregar:**

```yaml
{{- $root := . }}

{{/* Detectar si estamos en modo platform */}}
{{- $platformMode := include "platform.isEnabled" . }}

{{- if $platformMode }}
{{/*
  MODO PLATFORM WORKLOAD DEFINITION

  Cuando platform.enabled es true, los valores vienen de platform.*
  y necesitamos transformarlos antes de pasarlos a los templates de Summon.

  La transformación se hace en templates/platform.yaml y aquí solo
  necesitamos usar los valores transformados.
*/}}

{{/* Incluir el transformer de platform */}}
{{- include "platform.transformer" . }}

{{- else }}
{{/*
  MODO MICROSPELL NATIVO

  El flujo normal de microspell continúa sin cambios.
*/}}
{{- end }}
```

### Estructura del archivo modificado

```yaml
{{- $root := . }}
{{- $platformMode := include "platform.isEnabled" . }}

{{/* ===== MODO PLATFORM ===== */}}
{{- if $platformMode }}

  {{/* Las transformaciones se hacen en platform.yaml */}}
  {{/* Aquí incluimos ese template */}}

{{/* ===== MODO MICROSPELL NATIVO ===== */}}
{{- else }}

  {{/* Código original de base.yaml */}}

  {{- if .Values.workload.enabled -}}
  {{- include ( printf "summon.workload.%s" .Values.workload.type ) . }}
  {{- end -}}

  {{/* ... resto del código original ... */}}

{{- end }}
```

### Notas importantes

1. **Backward compatibility**: El código original solo se ejecuta si `platformMode` es false
2. **Separación de concerns**: La lógica de transformación está en `platform.yaml`
3. **El template platform.yaml genera los recursos directamente**

---

## 9. Fase 8: Crear Examples

### Objetivo
Crear archivos de ejemplo que demuestren el uso de PWD.

### Archivos a crear en `examples/`

#### platform-service-minimal.yaml
```yaml
# Ejemplo mínimo de service con Platform Workload Definition
platform:
  enabled: true
  version: "1.0"
  name: my-api
  namespace: my-team
  type: service

  image:
    repository: nginx
    tag: alpine
```

#### platform-service-with-scaling.yaml
```yaml
# Service con configuración de escalabilidad
platform:
  enabled: true
  name: order-api
  namespace: ecommerce
  type: service

  image:
    repository: registry.company.com/ecommerce/order-api
    tag: v2.1.0

  scalability:
    instances:
      min: 2
      max: 10
    resources:
      cpu: 1
      memory: 2
    scaling:
      metric: cpu
      threshold: 70
```

#### platform-service-with-ingress.yaml
```yaml
# Service expuesto públicamente con health checks
platform:
  enabled: true
  name: public-api
  namespace: platform
  type: service

  image:
    repository: registry.company.com/platform/api
    tag: v1.0.0

  ingress:
    enabled: true
    protocol: https
    port: 8080
    exposure: public
    rate-limiting:
      requests-per-second: 100
      burst: 200
    health:
      path: /health
      interval: 15
      timeout: 5
```

#### platform-job-minimal.yaml
```yaml
# Job básico
platform:
  enabled: true
  name: data-migration
  namespace: analytics
  type: job

  image:
    repository: registry.company.com/analytics/migrator
    tag: v1.0.0
```

#### platform-job-with-config.yaml
```yaml
# Job con configuración completa
platform:
  enabled: true
  name: report-generator
  namespace: analytics
  type: job

  image:
    repository: registry.company.com/analytics/report-gen
    tag: v1.5.2

  job:
    retries: 2
    timeout: 7200
    cleanup: on-success
    retention: 168h
    parallelism: 5
    completions: 100

  scalability:
    resources:
      cpu: 2
      memory: 8

  environment:
    - name: REPORT_MONTH
      value: "2025-01"
    - name: OUTPUT_FORMAT
      value: pdf
```

#### platform-cronjob-minimal.yaml
```yaml
# CronJob básico
platform:
  enabled: true
  name: cleanup-task
  namespace: platform
  type: cronjob

  image:
    repository: registry.company.com/platform/cleanup
    tag: v1.0.0

  cronjob:
    schedule: "0 3 * * *"  # Daily at 3:00 AM UTC
```

#### platform-cronjob-with-config.yaml
```yaml
# CronJob con configuración completa
platform:
  enabled: true
  name: expired-session-cleanup
  namespace: platform
  type: cronjob

  image:
    repository: registry.company.com/platform/cleanup-tools
    tag: v1.0.0

  cronjob:
    schedule: "0 3 * * *"
    concurrency: forbid
    retries: 1
    timeout: 1800
    history-limit: 5

  environment:
    - name: SESSION_TTL_HOURS
      value: "24"
    - name: DRY_RUN
      value: "false"
```

#### platform-with-vault-secrets.yaml
```yaml
# Service con secrets de Vault
platform:
  enabled: true
  name: payment-service
  namespace: payments
  type: service

  image:
    repository: registry.company.com/payments/service
    tag: v3.0.0

  policies:
    resources:
      - type: secrets-vault
        name: db-credentials
        access: read
        keys: [username, password, host, port]
      - type: secrets-vault
        name: stripe-api-key
        access: read
        keys: [api-key, webhook-secret]

  secrets:
    - key: db-credentials
      env: DATABASE_URL
    - key: stripe-api-key

  scalability:
    instances:
      min: 2
      max: 10
    resources:
      cpu: 0.5
      memory: 1
```

#### platform-with-database.yaml
```yaml
# Service con base de datos
platform:
  enabled: true
  name: user-service
  namespace: users
  type: service

  image:
    repository: registry.company.com/users/service
    tag: v2.0.0

  policies:
    resources:
      - type: relational-db
        name: users-db
        access: read-write
      - type: cache
        name: session-cache
        access: read-write

  scalability:
    instances:
      min: 2
      max: 20
    resources:
      cpu: 1
      memory: 2

  ingress:
    enabled: true
    protocol: https
    port: 8080
    exposure: internal
    health:
      path: /health
```

#### platform-full-stack.yaml
```yaml
# Ejemplo completo con todas las features
platform:
  enabled: true
  version: "1.0"
  name: order-api
  namespace: ecommerce
  type: service

  image:
    repository: registry.company.com/ecommerce/order-api
    tag: v2.1.0

  policies:
    resources:
      - type: relational-db
        name: orders-db
        access: read-write
      - type: message-queue
        name: order-events
        access: publish
      - type: cache
        name: order-cache
        access: read-write
      - type: secrets-vault
        name: api-credentials
        access: read
        keys: [stripe-key, sendgrid-key]

  secrets:
    - key: api-credentials

  scalability:
    instances:
      min: 2
      max: 20
    resources:
      cpu: 1
      memory: 2
    scaling:
      metric: cpu
      threshold: 60

  ingress:
    enabled: true
    protocol: https
    port: 443
    exposure: public
    rate-limiting:
      requests-per-second: 1000
      burst: 2000
    health:
      path: /api/health
      interval: 15

  environment:
    - name: LOG_LEVEL
      value: info
    - name: ENABLE_METRICS
      value: "true"

  labels:
    team: ecommerce
    cost-center: cc-5001

  annotations:
    owner: ecommerce-team@company.com
    documentation: https://wiki.company.com/order-api

# Kast system integration
spellbook:
  name: ecommerce
chapter:
  name: production
```

---

## 10. Fase 9: Testing

### Objetivo
Agregar tests para el modo platform.

### Agregar en Makefile

```makefile
# ==============================================================================
# Platform Workload Definition Tests
# ==============================================================================

test-microspell-platform: ## Test microspell platform mode examples
	@echo "Testing Platform Workload Definition mode..."
	@for f in charts/trinkets/microspell/examples/platform-*.yaml; do \
		echo "Testing $$f..."; \
		helm template test charts/trinkets/microspell -f $$f > /dev/null || exit 1; \
	done
	@echo "All platform tests passed!"

test-microspell-platform-verbose: ## Test microspell platform mode with output
	@for f in charts/trinkets/microspell/examples/platform-*.yaml; do \
		echo "=== Testing $$f ==="; \
		helm template test charts/trinkets/microspell -f $$f; \
		echo ""; \
	done
```

### Comandos de test

```bash
# Test básico (solo verifica que no hay errores)
make test-microspell-platform

# Test con output (muestra los recursos generados)
make test-microspell-platform-verbose

# Test individual
helm template test charts/trinkets/microspell -f charts/trinkets/microspell/examples/platform-service-minimal.yaml

# Test con debug
helm template test charts/trinkets/microspell -f charts/trinkets/microspell/examples/platform-service-minimal.yaml --debug
```

---

## 11. Fase 10: Documentación

### Archivos a actualizar

1. **charts/trinkets/microspell/README.md**: Agregar sección "Platform Workload Definition Mode"
2. **docs/PLATFORM_WORKLOAD.md**: Crear documentación completa (este archivo)
3. **docs/NAVIGATION.md**: Agregar link a la nueva documentación
4. **CLAUDE.md**: Agregar información sobre PWD

---

## 12. Mapeo Completo PWD → Microspell

### Propiedades Root

| PWD | Microspell | Notas |
|-----|------------|-------|
| `platform.name` | `name` | Directo |
| `platform.namespace` | `namespace` | Se usa en metadatos |
| `platform.type: service` | `workload.type: deployment` | Transformación |
| `platform.type: job` | `workload.type: job` | Directo |
| `platform.type: cronjob` | `workload.type: cronjob` | Directo |
| `platform.image` | `image` | Directo |

### Scalability

| PWD | Microspell | Notas |
|-----|------------|-------|
| `scalability.instances.min` | `workload.replicas` | También `autoscaling.minReplicas` |
| `scalability.instances.max` | `autoscaling.maxReplicas` | Solo si > min |
| `scalability.resources.cpu` | `resources.requests/limits.cpu` | Convertir a millicores |
| `scalability.resources.memory` | `resources.requests/limits.memory` | Convertir a Gi |
| `scalability.scaling.metric: cpu` | `autoscaling.targetCPUUtilizationPercentage` | |
| `scalability.scaling.metric: memory` | `autoscaling.targetMemoryUtilizationPercentage` | |

### Job Configuration

| PWD | Microspell | Notas |
|-----|------------|-------|
| `job.retries` | `workload.backoffLimit` | |
| `job.timeout` | `workload.activeDeadlineSeconds` | |
| `job.parallelism` | `workload.parallelism` | |
| `job.completions` | `workload.completions` | |
| `job.cleanup: always` | `workload.ttlSecondsAfterFinished: 0` | |
| `job.cleanup: on-success` | `workload.ttlSecondsAfterFinished: 100` | |
| `job.cleanup: never` | (no configurar TTL) | |
| `job.retention` | Parsear a segundos | 72h → 259200 |

### CronJob Configuration

| PWD | Microspell | Notas |
|-----|------------|-------|
| `cronjob.schedule` | `workload.schedule` | Requerido |
| `cronjob.concurrency: allow` | `workload.concurrencyPolicy: Allow` | |
| `cronjob.concurrency: forbid` | `workload.concurrencyPolicy: Forbid` | |
| `cronjob.concurrency: replace` | `workload.concurrencyPolicy: Replace` | |
| `cronjob.history-limit` | `workload.successfulJobsHistoryLimit` | |
| `cronjob.starting-deadline` | `workload.startingDeadlineSeconds` | |

### Ingress

| PWD | Microspell | Notas |
|-----|------------|-------|
| `ingress.enabled` | `service.enabled` | |
| `ingress.port` | `service.ports[0].port` | |
| `ingress.exposure: public` | `service.external: true` | También VirtualService |
| `ingress.exposure: internal` | `service.external: false` | |
| `ingress.health.path` | `probes.liveness/readiness.path` | |
| `ingress.health.interval` | `probes.*.periodSeconds` | |
| `ingress.health.timeout` | `probes.*.timeoutSeconds` | |

### Resources

| PWD Resource Type | Microspell Config |
|-------------------|-------------------|
| `secrets-vault` | `secrets:` |
| `relational-db` | `dataStore.psql:` |
| `object-storage` | glyph `s3` |
| `cache` | Según provider |
| `message-queue` | Según provider |
| `event-stream` | Según provider |

### Environment

| PWD | Microspell |
|-----|------------|
| `environment: [{name: X, value: Y}]` | `envs: {X: Y}` |

---

## 13. Preguntas Frecuentes

### ¿Puedo usar PWD y microspell nativo juntos?

No en el mismo archivo. Si `platform.enabled: true`, se usa PWD. Si es `false` o no existe, se usa microspell nativo.

### ¿Qué pasa con features de microspell no soportadas en PWD?

Puedes usar el escape hatch `glyphs:` para acceder a funcionalidades avanzadas:

```yaml
platform:
  enabled: true
  # ... configuración PWD ...

# Escape hatch para features avanzadas
glyphs:
  istio:
    - type: destinationRule
      name: custom-dr
      # ...
```

### ¿Cómo agrego un nuevo tipo de resource?

1. Agregar el tipo en el mapeo de `_platform.tpl`
2. Agregar el handler en `platform.yaml`
3. Agregar documentación
4. Crear example

### ¿El modo platform funciona con todos los glyphs existentes?

Sí, porque internamente transforma a formato microspell nativo que ya soporta todos los glyphs.

---

## Contacto

Para preguntas sobre esta implementación:
- **Slack**: #platform-support
- **Documentación**: docs/PLATFORM_WORKLOAD.md
