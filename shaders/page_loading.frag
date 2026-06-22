#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform float uTime;
uniform vec3 uColorA;
uniform vec3 uColorB;
uniform vec3 uColorC;

out vec4 fragColor;

float blob(vec2 uv, vec2 center, float radius) {
  float d = distance(uv, center);
  return smoothstep(radius, 0.0, d);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / max(uSize, vec2(1.0));
  float t = uTime * 0.18;

  vec2 p1 = vec2(0.30 + 0.08 * sin(t * 2.1), 0.35 + 0.06 * cos(t * 1.7));
  vec2 p2 = vec2(0.72 + 0.07 * cos(t * 1.4), 0.62 + 0.08 * sin(t * 1.9));
  vec2 p3 = vec2(0.48 + 0.05 * sin(t * 1.1), 0.78 + 0.05 * cos(t * 2.3));

  float b1 = blob(uv, p1, 0.62);
  float b2 = blob(uv, p2, 0.58);
  float b3 = blob(uv, p3, 0.44);

  vec3 color = uColorA;
  color = mix(color, uColorB, b1 * 0.55 + b2 * 0.35);
  color = mix(color, uColorC, b3 * 0.35);

  float grain = sin((uv.x + uv.y) * 80.0 + uTime * 0.7) * 0.015;
  fragColor = vec4(color + grain, 1.0);
}
