{{/*runik - Kubernetes arcane spelling technology
Copyright (C) 2026 kazapeke@gmail.com
Licensed under the GNU GPL v3. See LICENSE file for details.
*/}}
{{- define "aws.documentdb-instance" }}
{{- $root := index . 0 -}}
{{- $glyphDefinition := index . 1 }}

{{- $instanceCount := default 1 $glyphDefinition.instanceCount | int }}
{{- $clusterIdentifier := default (include "common.name" $root) $glyphDefinition.dbClusterIdentifier }}

{{- range $i := until $instanceCount }}
---
apiVersion: documentdb.services.k8s.aws/v1alpha1
kind: DBInstance
metadata:
  name: {{ $clusterIdentifier }}-{{ $i }}
  namespace: {{ default $root.Release.Namespace $glyphDefinition.namespace }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    app.kubernetes.io/component: documentdb-instance
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
  dbInstanceIdentifier: {{ $clusterIdentifier }}-{{ $i }}
  dbInstanceClass: {{ default "db.t3.medium" $glyphDefinition.instanceClass }}
  engine: docdb
  dbClusterIdentifier: {{ $clusterIdentifier }}

  {{- with $glyphDefinition.availabilityZone }}
  availabilityZone: {{ . }}
  {{- end }}

  autoMinorVersionUpgrade: {{ default true $glyphDefinition.autoMinorVersionUpgrade }}

  {{- /* Tags */}}
  {{- with $glyphDefinition.tags }}
  tags:
    {{- range . }}
    - key: {{ .key }}
      value: {{ .value }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}
