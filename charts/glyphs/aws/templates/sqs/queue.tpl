{{/*runik - Kubernetes arcane spelling technology
Copyright (C) 2026 kazapeke@gmail.com
Licensed under the GNU GPL v3. See LICENSE file for details.
*/}}
{{- define "aws.sqs-queue" }}
{{- $root := index . 0 -}}
{{- $glyphDefinition := index . 1 }}
---
apiVersion: sqs.services.k8s.aws/v1alpha1
kind: Queue
metadata:
  name: {{ default (include "common.name" $root) $glyphDefinition.name }}
  namespace: {{ default $root.Release.Namespace $glyphDefinition.namespace }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $glyphDefinition.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- if or $glyphDefinition.annotations $glyphDefinition.adoptionPolicy }}
  annotations:
    {{- if $glyphDefinition.adoptionPolicy }}
    services.k8s.aws/adoption-policy: {{ $glyphDefinition.adoptionPolicy }}
    {{- end }}
    {{- with $glyphDefinition.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- end }}
spec:
  queueName: {{ default (include "common.name" $root) $glyphDefinition.queueName }}

  {{- /* FIFO queue configuration */}}
  {{- if $glyphDefinition.fifo }}
  fifoQueue: "true"
  {{- with $glyphDefinition.contentBasedDeduplication }}
  contentBasedDeduplication: {{ . | quote }}
  {{- end }}
  {{- with $glyphDefinition.deduplicationScope }}
  deduplicationScope: {{ . | quote }}
  {{- end }}
  {{- with $glyphDefinition.fifoThroughputLimit }}
  fifoThroughputLimit: {{ . | quote }}
  {{- end }}
  {{- end }}

  {{- /* Message configuration */}}
  {{- with $glyphDefinition.delaySeconds }}
  delaySeconds: {{ . | quote }}
  {{- end }}
  {{- with $glyphDefinition.maximumMessageSize }}
  maximumMessageSize: {{ . | quote }}
  {{- end }}
  {{- with $glyphDefinition.messageRetentionPeriod }}
  messageRetentionPeriod: {{ . | quote }}
  {{- end }}
  {{- with $glyphDefinition.receiveMessageWaitTimeSeconds }}
  receiveMessageWaitTimeSeconds: {{ . | quote }}
  {{- end }}
  {{- with $glyphDefinition.visibilityTimeout }}
  visibilityTimeout: {{ . | quote }}
  {{- end }}

  {{- /* Encryption */}}
  {{- if $glyphDefinition.encryption }}
  {{- if $glyphDefinition.encryption.kmsKeyID }}
  kmsMasterKeyID: {{ $glyphDefinition.encryption.kmsKeyID | quote }}
  {{- with $glyphDefinition.encryption.kmsDataKeyReusePeriodSeconds }}
  kmsDataKeyReusePeriodSeconds: {{ . | quote }}
  {{- end }}
  {{- else }}
  sqsManagedSSEEnabled: {{ default "true" ($glyphDefinition.encryption.sqsManaged | quote) }}
  {{- end }}
  {{- else }}
  sqsManagedSSEEnabled: "true"
  {{- end }}

  {{- /* Dead letter queue */}}
  {{- with $glyphDefinition.redrivePolicy }}
  redrivePolicy: {{ . | toJson | quote }}
  {{- end }}
  {{- with $glyphDefinition.redriveAllowPolicy }}
  redriveAllowPolicy: {{ . | toJson | quote }}
  {{- end }}

  {{- /* Access policy */}}
  {{- with $glyphDefinition.policy }}
  policy: {{ . | toJson | quote }}
  {{- end }}

  {{- /* Tags */}}
  {{- if $glyphDefinition.tags }}
  tags:
    {{- range $key, $value := $glyphDefinition.tags }}
    {{ $key }}: {{ $value | quote }}
    {{- end }}
  {{- else }}
  tags:
    Name: {{ default (include "common.name" $root) $glyphDefinition.name }}
    ManagedBy: ack-sqs-controller
  {{- end }}
{{- end }}
