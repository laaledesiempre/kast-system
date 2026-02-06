{{/*runik - Kubernetes arcane spelling technology
Copyright (C) 2026 kazapeke@gmail.com
Licensed under the GNU GPL v3. See LICENSE file for details.
*/}}
{{- define "aws.msk-cluster" }}
{{- $root := index . 0 -}}
{{- $glyphDefinition := index . 1 }}
---
apiVersion: kafka.services.k8s.aws/v1alpha1
kind: Cluster
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
  clusterName: {{ default (include "common.name" $root) $glyphDefinition.clusterName }}
  kafkaVersion: {{ default "3.6.0" $glyphDefinition.kafkaVersion | quote }}
  numberOfBrokerNodes: {{ default 3 $glyphDefinition.numberOfBrokerNodes }}

  {{- /* Broker node group info */}}
  brokerNodeGroupInfo:
    instanceType: {{ default "kafka.m5.large" $glyphDefinition.instanceType }}
    {{- if $glyphDefinition.clientSubnets }}
    clientSubnets:
      {{- range $glyphDefinition.clientSubnets }}
      - {{ . }}
      {{- end }}
    {{- else if $glyphDefinition.subnetSelector }}
      {{- $subnets := get (include "runicIndexer.runicIndexer" (list $root.Values.lexicon (default dict $glyphDefinition.subnetSelector) "aws-subnet" $root.Values.chapter.name) | fromJson) "results" }}
    clientSubnets:
      {{- range $subnet := $subnets }}
      - {{ $subnet.id }}
      {{- end }}
    {{- end }}
    {{- if $glyphDefinition.securityGroups }}
    securityGroups:
      {{- range $glyphDefinition.securityGroups }}
      {{- if .id }}
      - {{ .id }}
      {{- else if .selector }}
        {{- $results := get (include "runicIndexer.runicIndexer" (list $root.Values.lexicon (default dict .selector) "aws-security-group" $root.Values.chapter.name) | fromJson) "results" }}
        {{- range $result := $results }}
      - {{ $result.id }}
        {{- end }}
      {{- end }}
      {{- end }}
    {{- end }}
    storageInfo:
      ebsStorageInfo:
        volumeSize: {{ default 100 $glyphDefinition.storageSize }}
        {{- if $glyphDefinition.provisionedThroughput }}
        provisionedThroughput:
          enabled: {{ default false $glyphDefinition.provisionedThroughput.enabled }}
          {{- with $glyphDefinition.provisionedThroughput.volumeThroughput }}
          volumeThroughput: {{ . }}
          {{- end }}
        {{- end }}
    {{- with $glyphDefinition.connectivityInfo }}
    connectivityInfo:
      {{- with .publicAccess }}
      publicAccess:
        type: {{ default "DISABLED" .type | quote }}
      {{- end }}
    {{- end }}

  {{- /* Client authentication */}}
  {{- if $glyphDefinition.authentication }}
  clientAuthentication:
    {{- if $glyphDefinition.authentication.sasl }}
    sasl:
      {{- with $glyphDefinition.authentication.sasl.iam }}
      iam:
        enabled: {{ default true . }}
      {{- end }}
      {{- with $glyphDefinition.authentication.sasl.scram }}
      scram:
        enabled: {{ default false . }}
      {{- end }}
    {{- end }}
    {{- if $glyphDefinition.authentication.tls }}
    tls:
      enabled: {{ default false $glyphDefinition.authentication.tls.enabled }}
      {{- with $glyphDefinition.authentication.tls.certificateAuthorityARNList }}
      certificateAuthorityARNList:
        {{- range . }}
        - {{ . }}
        {{- end }}
      {{- end }}
    {{- end }}
    {{- if $glyphDefinition.authentication.unauthenticated }}
    unauthenticated:
      enabled: {{ $glyphDefinition.authentication.unauthenticated.enabled }}
    {{- end }}
  {{- else }}
  clientAuthentication:
    sasl:
      iam:
        enabled: true
    unauthenticated:
      enabled: false
  {{- end }}

  {{- /* Encryption */}}
  {{- if $glyphDefinition.encryption }}
  encryptionInfo:
    {{- if $glyphDefinition.encryption.inTransit }}
    encryptionInTransit:
      clientBroker: {{ default "TLS" $glyphDefinition.encryption.inTransit.clientBroker }}
      inCluster: {{ default true $glyphDefinition.encryption.inTransit.inCluster }}
    {{- end }}
    {{- with $glyphDefinition.encryption.atRest }}
    encryptionAtRest:
      {{- with .kmsKeyARN }}
      dataVolumeKMSKeyID: {{ . }}
      {{- end }}
    {{- end }}
  {{- else }}
  encryptionInfo:
    encryptionInTransit:
      clientBroker: TLS
      inCluster: true
  {{- end }}

  {{- /* Configuration info */}}
  {{- with $glyphDefinition.configurationInfo }}
  configurationInfo:
    arn: {{ .arn }}
    revision: {{ default 1 .revision }}
  {{- end }}

  {{- /* Enhanced monitoring */}}
  {{- with $glyphDefinition.enhancedMonitoring }}
  enhancedMonitoring: {{ . }}
  {{- end }}

  {{- /* Logging */}}
  {{- with $glyphDefinition.logging }}
  loggingInfo:
    {{- with .cloudWatchLogs }}
    brokerLogs:
      cloudWatchLogs:
        enabled: {{ default false .enabled }}
        {{- with .logGroup }}
        logGroup: {{ . }}
        {{- end }}
    {{- end }}
    {{- with .s3 }}
      s3:
        enabled: {{ default false .enabled }}
        {{- with .bucket }}
        bucket: {{ . }}
        {{- end }}
        {{- with .prefix }}
        prefix: {{ . }}
        {{- end }}
    {{- end }}
  {{- end }}

  {{- /* Tags */}}
  {{- with $glyphDefinition.tags }}
  tags:
    {{- range $key, $value := . }}
    {{ $key }}: {{ $value | quote }}
    {{- end }}
  {{- end }}
{{- end }}
