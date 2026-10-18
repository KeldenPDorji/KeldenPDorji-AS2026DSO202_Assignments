#!/usr/bin/env ruby
# Reads a rendered multi-document Kubernetes YAML stream and prints the few
# fields the overlay comparison cares about, one "key=value" per line.
#
# Parsing the YAML rather than grepping it matters here: the fields being
# compared (a Service's type, a Deployment's replicas) sit at different line
# offsets in each document, and a grep with a fixed -A window silently reports
# "not found" when the document grows.
require 'yaml'

docs = YAML.load_stream(ARGF.read).compact
out  = {}

out['objects'] = docs.size
out['namespace'] = docs.map { |d| d.dig('metadata', 'namespace') }.compact.uniq.first || '-'

docs.each do |d|
  kind = d['kind']
  name = d.dig('metadata', 'name').to_s

  case kind
  when 'Deployment'
    tier = name.split('-').last
    out["replicas.#{tier}"] = d.dig('spec', 'replicas')
    c = d.dig('spec', 'template', 'spec', 'containers', 0)
    out["image.#{tier}"]  = c['image']
    out["cpulimit.#{tier}"] = c.dig('resources', 'limits', 'cpu')
  when 'Service'
    next unless name.end_with?('frontend-svc', '-frontend')
    out['frontend.type']     = d.dig('spec', 'type')
    out['frontend.nodePort'] = d.dig('spec', 'ports', 0, 'nodePort') || 'absent'
    ann = d.dig('metadata', 'annotations') || {}
    out['frontend.annotation'] = ann.map { |k, v| "#{k}=#{v}" }.join(',')
    out['frontend.annotation'] = '-' if out['frontend.annotation'].empty?
  when 'ConfigMap'
    next if name.include?('root-ca')
    out['configmap.name'] = name
    out['CORS_ORIGIN']    = d.dig('data', 'CORS_ORIGIN')
    out['BACKEND_URL']    = d.dig('data', 'BACKEND_URL')
  when 'Secret'
    out['secret.name'] = name
  end
end

out.each { |k, v| puts "#{k}=#{v}" }
