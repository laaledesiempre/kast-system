{{/*runik - Kubernetes arcane spelling technology
Copyright (C) 2026 kazapeke@gmail.com
Licensed under the GNU GPL v3. See LICENSE file for details.
*/}}
{{- define "aws.elasticache-replication-group" }}
{{- $root := index . 0 -}}
{{- $glyphDefinition := index . 1 }}
---
apiVersion: elasticache.services.k8s.aws/v1alpha1
kind: ReplicationGroup
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
  replicationGroupID: {{ default (include "common.name" $root) $glyphDefinition.replicationGroupID }}
  replicationGroupDescription: {{ default (printf "Managed by runik - %s" (default (include "common.name" $root) $glyphDefinition.name)) $glyphDefinition.description | quote }}

  {{- /* Engine configuration */}}
  engine: {{ default "redis" $glyphDefinition.engine }}
  {{- with $glyphDefinition.engineVersion }}
  engineVersion: {{ . | quote }}
  {{- end }}
  cacheNodeType: {{ default "cache.t3.micro" $glyphDefinition.nodeType }}

  {{- /* Cluster topology */}}
  {{- if $glyphDefinition.numNodeGroups }}
  numNodeGroups: {{ $glyphDefinition.numNodeGroups }}
  replicasPerNodeGroup: {{ default 1 $glyphDefinition.replicasPerNodeGroup }}
  {{- else }}
  numCacheClusters: {{ default 2 $glyphDefinition.numCacheClusters }}
  {{- end }}

  automaticFailoverEnabled: {{ default true $glyphDefinition.automaticFailoverEnabled }}
  multiAZEnabled: {{ default true $glyphDefinition.multiAZEnabled }}

  {{- /* Networking */}}
  {{- if $glyphDefinition.cacheSubnetGroupName }}
  cacheSubnetGroupName: {{ $glyphDefinition.cacheSubnetGroupName }}
  {{- else if $glyphDefinition.subnetGroup }}
    {{- if $glyphDefinition.subnetGroup.name }}
  cacheSubnetGroupName: {{ $glyphDefinition.subnetGroup.name }}
    {{- else if $glyphDefinition.subnetGroup.selector }}
      {{- $results := get (include "runicIndexer.runicIndexer" (list $root.Values.lexicon (default dict $glyphDefinition.subnetGroup.selector) "aws-elasticache-subnet-group" $root.Values.chapter.name) | fromJson) "results" }}
      {{- range $result := $results }}
  cacheSubnetGroupName: {{ $result.name }}
      {{- end }}
    {{- end }}
  {{- end }}

  {{- if $glyphDefinition.securityGroupIDs }}
  securityGroupIDs:
    {{- range $glyphDefinition.securityGroupIDs }}
    - {{ . }}
    {{- end }}
  {{- else if $glyphDefinition.securityGroups }}
  securityGroupIDs:
    {{- range $sg := $glyphDefinition.securityGroups }}
      {{- if $sg.id }}
    - {{ $sg.id }}
      {{- else if $sg.selector }}
        {{- $results := get (include "runicIndexer.runicIndexer" (list $root.Values.lexicon (default dict $sg.selector) "aws-security-group" $root.Values.chapter.name) | fromJson) "results" }}
        {{- range $result := $results }}
    - {{ $result.id }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}

  port: {{ default 6379 $glyphDefinition.port }}

  {{- /* Parameter group */}}
  {{- if $glyphDefinition.cacheParameterGroupName }}
  cacheParameterGroupName: {{ $glyphDefinition.cacheParameterGroupName }}
  {{- else if $glyphDefinition.parameterGroup }}
    {{- if $glyphDefinition.parameterGroup.name }}
  cacheParameterGroupName: {{ $glyphDefinition.parameterGroup.name }}
    {{- else if $glyphDefinition.parameterGroup.selector }}
      {{- $results := get (include "runicIndexer.runicIndexer" (list $root.Values.lexicon (default dict $glyphDefinition.parameterGroup.selector) "aws-elasticache-parameter-group" $root.Values.chapter.name) | fromJson) "results" }}
      {{- range $result := $results }}
  cacheParameterGroupName: {{ $result.name }}
      {{- end }}
    {{- end }}
  {{- end }}

  {{- /* Encryption */}}
  atRestEncryptionEnabled: {{ default true $glyphDefinition.atRestEncryptionEnabled }}
  transitEncryptionEnabled: {{ default true $glyphDefinition.transitEncryptionEnabled }}
  {{- with $glyphDefinition.transitEncryptionMode }}
  transitEncryptionMode: {{ . }}
  {{- end }}
  {{- with $glyphDefinition.kmsKeyID }}
  kmsKeyID: {{ . }}
  {{- end }}

  {{- /* Auth token (password) */}}
  {{- with $glyphDefinition.authToken }}
  authToken:
    name: {{ .name }}
    key: {{ default "password" .key }}
    {{- with .namespace }}
    namespace: {{ . }}
    {{- end }}
  {{- end }}

  {{- /* Snapshot and backup */}}
  {{- with $glyphDefinition.snapshotRetentionLimit }}
  snapshotRetentionLimit: {{ . }}
  {{- end }}
  {{- with $glyphDefinition.snapshotWindow }}
  snapshotWindow: {{ . | quote }}
  {{- end }}

  {{- /* Maintenance */}}
  {{- with $glyphDefinition.preferredMaintenanceWindow }}
  preferredMaintenanceWindow: {{ . | quote }}
  {{- end }}
  autoMinorVersionUpgrade: {{ default true $glyphDefinition.autoMinorVersionUpgrade }}

  {{- /* Notification */}}
  {{- with $glyphDefinition.notificationTopicARN }}
  notificationTopicARN: {{ . }}
  {{- end }}

  {{- /* Tags */}}
  {{- with $glyphDefinition.tags }}
  tags:
    {{- range . }}
    - key: {{ .key }}
      value: {{ .value }}
    {{- end }}
  {{- end }}
{{- end }}
