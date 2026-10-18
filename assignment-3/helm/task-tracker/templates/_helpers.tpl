{{/*
_helpers.tpl - named templates shared by every file in templates/.
Files whose names begin with an underscore never produce Kubernetes objects.

Every name is prefixed with the chart name, because named templates are global
across a chart and all of its subcharts. Two charts that both defined "labels"
would silently overwrite each other.
*/}}

{{/* task-tracker.name: the chart name, or nameOverride when set. */}}
{{- define "task-tracker.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
task-tracker.fullname: the base name every object is derived from.
Truncated to 63 characters, the Kubernetes limit for a DNS label. If the
release name already contains the chart name, it is used alone, so a release
called task-tracker does not produce "task-tracker-task-tracker".
*/}}
{{- define "task-tracker.fullname" -}}
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

{{/* task-tracker.chart: "<name>-<version>" for the helm.sh/chart label.
     SemVer allows "+" in build metadata, which label values may not contain. */}}
{{- define "task-tracker.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
task-tracker.environment: the environment name.
config.environment wins; global.environment is the fallback a parent chart
would set. "required" stops rendering with this message when both are empty,
so the chart cannot produce an object without an environment.
*/}}
{{- define "task-tracker.environment" -}}
{{- required "config.environment must be set (dev, staging or prod)" (.Values.config.environment | default .Values.global.environment) }}
{{- end }}

{{/*
task-tracker.selectorLabels: the small, stable set that selectors match on.
These must never change after the first install, because a Deployment's
spec.selector is immutable and a Service's selector decides routing. Each
workload adds its own app.kubernetes.io/component on top of these.
*/}}
{{- define "task-tracker.selectorLabels" -}}
app.kubernetes.io/name: {{ include "task-tracker.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
task-tracker.labels: the full recommended label set for every object.
It deliberately includes labels that CHANGE between versions - helm.sh/chart
and app.kubernetes.io/version - which is exactly why it is kept separate from
the selector set above.
*/}}
{{- define "task-tracker.labels" -}}
helm.sh/chart: {{ include "task-tracker.chart" . }}
{{ include "task-tracker.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
dso202/environment: {{ include "task-tracker.environment" . | quote }}
{{- end }}

{{/*
task-tracker.image: builds one image reference from the registry, a tier's
image name and its tag, falling back to .Chart.AppVersion when the tag is
empty. Called with a dict so it can take two arguments:
  {{ include "task-tracker.image" (dict "root" . "tier" .Values.backend) }}
*/}}
{{- define "task-tracker.image" -}}
{{- $root := .root -}}
{{- $tier := .tier -}}
{{- printf "%s/%s:%s" $root.Values.image.registry $tier.image ($tier.tag | default $root.Chart.AppVersion) -}}
{{- end }}
