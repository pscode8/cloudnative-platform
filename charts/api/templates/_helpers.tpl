{{/*
Common labels — applied to ALL resources in this chart.
Kubernetes uses these for: filtering, monitoring, cost allocation.
*/}}
{{- define "cloudnative-api.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "cloudnative-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: api
app.kubernetes.io/part-of: cloudnative-platform
{{- end }}
 
{{/*
Selector labels — used by Services to find pods.
Must be stable — changing these breaks service discovery.
*/}}
{{- define "cloudnative-api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cloudnative-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
 
{{/*
Service account name
*/}}
{{- define "cloudnative-api.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cloudnative-api.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}