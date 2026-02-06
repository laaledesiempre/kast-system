{{/*runik - Kubernetes arcane spelling technology
Copyright (C) 2026 kazapeke@gmail.com
Licensed under the GNU GPL v3. See LICENSE file for details.
*/}}
{{- define "aws.documentdb-cluster" }}
{{- $root := index . 0 -}}
{{- $glyphDefinition := index . 1 }}
---
apiVersion: documentdb.services.k8s.aws/v1alpha1
kind: DBCluster
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
  dbClusterIdentifier: {{ default (include "common.name" $root) $glyphDefinition.dbClusterIdentifier }}
  engine: {{ default "docdb" $glyphDefinition.engine }}
  {{- with $glyphDefinition.engineVersion }}
  engineVersion: {{ . | quote }}
  {{- end }}

  {{- /* Master credentials */}}
  {{- with $glyphDefinition.masterUsername }}
  masterUsername: {{ . }}
  {{- end }}
  {{- with $glyphDefinition.masterUserPassword }}
  masterUserPassword:
    name: {{ .name }}
    key: {{ default "password" .key }}
    {{- with .namespace }}
    namespace: {{ . }}
    {{- end }}
  {{- end }}

  {{- /* Networking */}}
  {{- if $glyphDefinition.dbSubnetGroupName }}
  dbSubnetGroupName: {{ $glyphDefinition.dbSubnetGroupName }}
  {{- else if $glyphDefinition.subnetGroup }}
    {{- if $glyphDefinition.subnetGroup.name }}
  dbSubnetGroupName: {{ $glyphDefinition.subnetGroup.name }}
    {{- else if $glyphDefinition.subnetGroup.selector }}
      {{- $results := get (include "runicIndexer.runicIndexer" (list $root.Values.lexicon (default dict $glyphDefinition.subnetGroup.selector) "aws-db-subnet-group" $root.Values.chapter.name) | fromJson) "results" }}
      {{- range $result := $results }}
  dbSubnetGroupName: {{ $result.name }}
      {{- end }}
    {{- end }}
  {{- end }}

  {{- if $glyphDefinition.vpcSecurityGroupIDs }}
  vpcSecurityGroupIDs:
    {{- range $glyphDefinition.vpcSecurityGroupIDs }}
    - {{ . }}
    {{- end }}
  {{- else if $glyphDefinition.securityGroups }}
  vpcSecurityGroupIDs:
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

  port: {{ default 27017 $glyphDefinition.port }}

  {{- /* Parameter group */}}
  {{- with $glyphDefinition.dbClusterParameterGroupName }}
  dbClusterParameterGroupName: {{ . }}
  {{- end }}

  {{- /* Availability zones */}}
  {{- with $glyphDefinition.availabilityZones }}
  availabilityZones:
    {{- range . }}
    - {{ . }}
    {{- end }}
  {{- end }}

  {{- /* Backup */}}
  backupRetentionPeriod: {{ default 7 $glyphDefinition.backupRetentionPeriod }}
  {{- with $glyphDefinition.preferredBackupWindow }}
  preferredBackupWindow: {{ . | quote }}
  {{- end }}

  {{- /* Maintenance */}}
  {{- with $glyphDefinition.preferredMaintenanceWindow }}
  preferredMaintenanceWindow: {{ . | quote }}
  {{- end }}

  {{- /* Encryption */}}
  storageEncrypted: {{ default true $glyphDefinition.storageEncrypted }}
  {{- with $glyphDefinition.kmsKeyID }}
  kmsKeyID: {{ . }}
  {{- end }}

  {{- /* Protection */}}
  deletionProtection: {{ default false $glyphDefinition.deletionProtection }}

  {{- /* Logging */}}
  {{- with $glyphDefinition.enableCloudwatchLogsExports }}
  enableCloudwatchLogsExports:
    {{- range . }}
    - {{ . }}
    {{- end }}
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
