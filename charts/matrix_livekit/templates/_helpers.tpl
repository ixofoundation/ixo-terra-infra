{{/*
Expand the name of the chart.
*/}}
{{- define "matrix-livekit.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "matrix-livekit.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "matrix-livekit.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "matrix-livekit.labels" -}}
helm.sh/chart: {{ include "matrix-livekit.chart" . }}
{{ include "matrix-livekit.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "matrix-livekit.selectorLabels" -}}
app.kubernetes.io/name: {{ include "matrix-livekit.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "matrix-livekit.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "matrix-livekit.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the secret to use
*/}}
{{- define "matrix-livekit.secretName" -}}
{{- if .Values.secrets.create }}
{{- default (printf "%s-secrets" (include "matrix-livekit.fullname" .)) .Values.secrets.name }}
{{- else }}
{{- .Values.secrets.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the configmap to use
*/}}
{{- define "matrix-livekit.configMapName" -}}
{{- if .Values.configMap.create }}
{{- default (include "matrix-livekit.fullname" .) .Values.configMap.name }}
{{- else }}
{{- .Values.configMap.name }}
{{- end }}
{{- end }} 