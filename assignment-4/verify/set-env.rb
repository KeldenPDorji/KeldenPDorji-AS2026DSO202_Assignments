#!/usr/bin/env ruby
# Sets <tier>.extraEnv in both environment values files.
# Usage: set-env.rb <tier> KEY=value [KEY=value ...]
tier, *pairs = ARGV
%w[dev staging].each do |e|
  f = "environments/#{e}/values.yaml"; s = File.read(f)
  block = pairs.map { |p| k, v = p.split('=', 2); %(    #{k}: "#{v}"\n) }.join
  s = s.sub(/^(#{tier}:\n  replicaCount: 1\n  tag: "1\.0"\n)(  extraEnv:\n(?:    .*\n)+)?/) { "#{$1}  extraEnv:\n#{block}" }
  File.write(f, s)
end
