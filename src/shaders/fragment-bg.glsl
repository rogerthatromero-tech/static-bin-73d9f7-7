#version 300 es

precision highp float;

in vec2 v_uv;
out vec4 fragColor;

uniform vec2 u_resolution;
uniform float u_dpr;
uniform vec2 u_mouse;
uniform vec2 u_mouseSpring;
uniform float u_time;
uniform float u_mergeRate;
uniform float u_shapeWidth;
uniform float u_shapeHeight;
uniform float u_shapeRadius;
uniform float u_shapeRoundness;
uniform float u_shadowExpand;
uniform float u_shadowFactor;
uniform vec2 u_shadowPosition;
uniform int u_bgType;
uniform sampler2D u_bgTexture;
uniform float u_bgTextureRatio;
uniform int u_bgTextureReady;
uniform vec4 u_bgTintColor;
uniform int u_showShape1;
uniform float u_shape1Width;
uniform float u_shape1Height;
uniform float u_shape2Width;
uniform float u_shape2Height;
uniform float u_shape3Width;
uniform float u_shape3Height;
uniform float u_shape4Width;
uniform float u_shape4Height;
uniform float u_shape5Width;
uniform float u_shape5Height;
uniform float u_shapesBorderRadius;
uniform float u_shapes123HorizontalOffset;
uniform float u_shape5HorizontalOffset;
uniform float u_shape4HorizontalOffset;
uniform float u_shapes123VerticalSpacing;

float chessboard(vec2 uv, float size, int mode) {
  float yBars = step(size * 2.0, mod(uv.y * 2.0, size * 4.0));
  float xBars = step(size * 2.0, mod(uv.x * 2.0, size * 4.0));

  if (mode == 0) {
    return yBars;
  } else if (mode == 1) {
    return xBars;
  } else {
    return abs(yBars - xBars);
  }
}

float halfColor(vec2 uv) {
  if (uv.y > 0.5) {
    return 1.0;
  } else {
    return 0.0;
  }
}

float sdCircle(vec2 p, float r) {
  return length(p) - r;
}

// Simple rounded rectangle SDF
float sdRoundedBox(vec2 p, vec2 b, float r) {
  vec2 d = abs(p) - b + r;
  return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

float superellipseCornerSDF(vec2 p, float r, float n) {
  p = abs(p);
  float v = pow(pow(p.x, n) + pow(p.y, n), 1.0 / n);
  return v - r;
}

float roundedRectSDF(vec2 p, vec2 center, float width, float height, float cornerRadius, float n) {
  // 移动到中心坐标系
  p -= center;

  float cr = cornerRadius * u_dpr;

  // 计算到矩形边缘的距离
  vec2 d = abs(p) - vec2(width * u_dpr, height * u_dpr) * 0.5;

  // 对于边缘区域和角落，我们需要不同的处理
  float dist;

  if (d.x > -cr && d.y > -cr) {
    // 角落区域
    vec2 cornerCenter = sign(p) * (vec2(width * u_dpr, height * u_dpr) * 0.5 - vec2(cr));
    vec2 cornerP = p - cornerCenter;
    dist = superellipseCornerSDF(cornerP, cr, n);
  } else {
    // 内部和边缘区域
    dist = min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
  }

  return dist;
}

float smin(float a, float b, float k) {
  float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
  return mix(b, a, h) - k * h * (1.0 - h);
}

float sdgMin(float a, float b) {
  return a < b
    ? a
    : b;
}

float mainSDF(vec2 p1, vec2 p2, vec2 p) {
  vec2 p1n = p1 + p / u_resolution.y;
  vec2 p2n = p2 + p / u_resolution.y;
  
  // Create 5 squares: 3 stacked on left, 1 in center, 1 on right
  float horizontalSpacing = 200.0 * u_dpr / u_resolution.y;
  float verticalSpacing = 150.0 * u_dpr / u_resolution.y;
  float shapes123Offset = u_shapes123HorizontalOffset * u_dpr / u_resolution.y;
  float shape5Offset = u_shape5HorizontalOffset * u_dpr / u_resolution.y;
  float shape4Offset = u_shape4HorizontalOffset * u_dpr / u_resolution.y;
  float shapes123VSpacing = u_shapes123VerticalSpacing * u_dpr / u_resolution.y;
  
  // Right column: 3 squares stacked vertically
  float s1 = sdRoundedBox(
    p1n + vec2(horizontalSpacing + shapes123Offset, shapes123VSpacing),
    vec2(u_shape1Width, u_shape1Height) * 0.5 * u_dpr / u_resolution.y,
    u_shapesBorderRadius * u_dpr / u_resolution.y
  );
  
  float s2 = sdRoundedBox(
    p1n + vec2(horizontalSpacing + shapes123Offset, 0.0),
    vec2(u_shape2Width, u_shape2Height) * 0.5 * u_dpr / u_resolution.y,
    u_shapesBorderRadius * u_dpr / u_resolution.y
  );
  
  float s3 = sdRoundedBox(
    p1n + vec2(horizontalSpacing + shapes123Offset, -shapes123VSpacing),
    vec2(u_shape3Width, u_shape3Height) * 0.5 * u_dpr / u_resolution.y,
    u_shapesBorderRadius * u_dpr / u_resolution.y
  );
  
  // Center square
  float s4 = sdRoundedBox(
    p1n + vec2(shape4Offset, 0.0),
    vec2(u_shape4Width, u_shape4Height) * 0.5 * u_dpr / u_resolution.y,
    u_shapesBorderRadius * u_dpr / u_resolution.y
  );
  
  // Left square
  float s5 = sdRoundedBox(
    p1n + vec2(-horizontalSpacing + shape5Offset, 0.0),
    vec2(u_shape5Width, u_shape5Height) * 0.5 * u_dpr / u_resolution.y,
    u_shapesBorderRadius * u_dpr / u_resolution.y
  );
  
  // Merge the 5 squares
  float squares = s1;
  squares = smin(squares, s2, u_mergeRate);
  squares = smin(squares, s3, u_mergeRate);
  squares = smin(squares, s4, u_mergeRate);
  squares = smin(squares, s5, u_mergeRate);
  
  float d1 = u_showShape1 == 1 ? squares : 1.0;
  
  // Cursor shape - circle with fixed radius
  float d2 = sdCircle(p2n, 20.0 * u_dpr / u_resolution.y);

  return smin(d1, d2, u_mergeRate);
}

// 输入：原始 uv、canvas 宽高比、纹理宽高比
// 输出：变换后的 uv，可直接用于 texture 采样
vec2 getCoverUV(vec2 uv, float canvasAspect, float textureAspect) {
  if (canvasAspect > textureAspect) {
    // canvas 更宽，纹理竖向拉伸
    float scale = textureAspect / canvasAspect;
    uv.y = uv.y * scale + 0.5 - 0.5 * scale;
  } else {
    // canvas 更高，纹理横向拉伸
    float scale = canvasAspect / textureAspect;
    uv.x = uv.x * scale + 0.5 - 0.5 * scale;
  }
  return uv;
}

// Convert RGB to HSL
vec3 rgb2hsl(vec3 color) {
  float maxC = max(max(color.r, color.g), color.b);
  float minC = min(min(color.r, color.g), color.b);
  float delta = maxC - minC;
  
  vec3 hsl = vec3(0.0);
  
  // Lightness
  hsl.z = (maxC + minC) / 2.0;
  
  if (delta == 0.0) {
    // Achromatic
    hsl.x = 0.0;
    hsl.y = 0.0;
  } else {
    // Saturation
    hsl.y = hsl.z < 0.5 ? delta / (maxC + minC) : delta / (2.0 - maxC - minC);
    
    // Hue
    if (color.r == maxC) {
      hsl.x = (color.g - color.b) / delta + (color.g < color.b ? 6.0 : 0.0);
    } else if (color.g == maxC) {
      hsl.x = (color.b - color.r) / delta + 2.0;
    } else {
      hsl.x = (color.r - color.g) / delta + 4.0;
    }
    hsl.x /= 6.0;
  }
  
  return hsl;
}

// Convert HSL to RGB
vec3 hsl2rgb(vec3 hsl) {
  float h = hsl.x;
  float s = hsl.y;
  float l = hsl.z;
  
  if (s == 0.0) {
    return vec3(l);
  }
  
  float q = l < 0.5 ? l * (1.0 + s) : l + s - l * s;
  float p = 2.0 * l - q;
  
  vec3 rgb;
  rgb.r = h + 1.0 / 3.0;
  rgb.g = h;
  rgb.b = h - 1.0 / 3.0;
  
  for (int i = 0; i < 3; i++) {
    if (rgb[i] < 0.0) rgb[i] += 1.0;
    if (rgb[i] > 1.0) rgb[i] -= 1.0;
    
    if (rgb[i] < 1.0 / 6.0)
      rgb[i] = p + (q - p) * 6.0 * rgb[i];
    else if (rgb[i] < 0.5)
      rgb[i] = q;
    else if (rgb[i] < 2.0 / 3.0)
      rgb[i] = p + (q - p) * (2.0 / 3.0 - rgb[i]) * 6.0;
    else
      rgb[i] = p;
  }
  
  return rgb;
}

void main() {
  vec2 u_resolution1x = u_resolution.xy / u_dpr;
  // float chessboardBg = chessboard(gl_FragCoord.xy, 14.0);
  vec3 bgColor = vec3(1.0);

  if (u_bgType <= 0) {
    // chessboard
    bgColor = vec3(1.0 - chessboard(gl_FragCoord.xy / u_dpr, 20.0, 2) / 4.0);
  } else if (u_bgType <= 1) {
    if (v_uv.x < 0.5 && v_uv.y > 0.5) {
      bgColor = vec3(chessboard(gl_FragCoord.xy / u_dpr, 10.0, 0));
    } else if (v_uv.x > 0.5 && v_uv.y < 0.5) {
      bgColor = vec3(chessboard(gl_FragCoord.xy / u_dpr, 10.0, 1));
    } else if (v_uv.x < 0.5 && v_uv.y < 0.5) {
      bgColor = vec3(0.0);
    }
  } else if (u_bgType <= 2) {
    bgColor = vec3(halfColor(gl_FragCoord.xy / u_resolution) * 0.6 + 0.3);
  } else if (u_bgType <= 11) {
    if (u_bgTextureReady != 1) {
      // chessboard
      bgColor = vec3(1.0 - chessboard(gl_FragCoord.xy / u_dpr, 20.0, 2) / 4.0);
    } else {
      vec2 uv = getCoverUV(v_uv, u_resolution.x / u_resolution.y, u_bgTextureRatio);

      // 不需要判断越界，CLAMP_TO_EDGE 会自动处理
      bgColor = texture(u_bgTexture, uv).rgb;
    }
  }

  // float chessboardBg = 1.0 - chessboard(gl_FragCoord.xy / u_dpr, 10.0) / 4.0;
  // float halfColorBg = halfColor(gl_FragCoord.xy / u_resolution);

  // draw shadow
  // center of shape 1
  vec2 p1 =
    (vec2(0, 0) -
      u_resolution.xy * 0.5 +
      vec2(u_shadowPosition.x * u_dpr, u_shadowPosition.y * u_dpr)) /
    u_resolution.y;
  // center of shape 2
  vec2 p2 =
    (vec2(0, 0) - u_mouseSpring + vec2(u_shadowPosition.x * u_dpr, u_shadowPosition.y * u_dpr)) /
    u_resolution.y;
  // merged shape
  float merged = mainSDF(p1, p2, gl_FragCoord.xy);

  float shadow = exp(-1.0 / u_shadowExpand * abs(merged) * u_resolution1x.y) * 0.6 * u_shadowFactor;

  vec3 color = bgColor - vec3(shadow);
  
  // Apply background tint using color blend mode (preserves luminosity)
  if (u_bgTintColor.a > 0.0) {
    vec3 bgHSL = rgb2hsl(color);
    vec3 tintHSL = rgb2hsl(u_bgTintColor.rgb);
    
    // Use hue and saturation from tint, luminosity from background
    vec3 blended = hsl2rgb(vec3(tintHSL.x, tintHSL.y, bgHSL.z));
    
    // Mix based on alpha and luminosity (don't affect very dark areas)
    float luminosityFactor = smoothstep(0.0, 0.3, bgHSL.z);
    color = mix(color, blended, u_bgTintColor.a * luminosityFactor);
  }
  
  fragColor = vec4(color, 1.0);
}
