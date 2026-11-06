--!strict
--!native
-- ══════════════════════════════════════════════════════════════════════
-- NVStudio Subsystem: nv_curves
-- Deskripsi: Mesin Kurva Cubic Bezier, Easing Functions & Quaternion SLERP
-- Menghitung interpolasi waktu dan rotasi sendi secara ultra-halus
-- layaknya kurva Graph Editor animator profesional.
-- ══════════════════════════════════════════════════════════════════════

local Curves = {}
local PI = math.pi
local HALF_PI = math.pi * 0.5
local TAU = math.pi * 2
local DEFAULT_OVERSHOOT = 1.70158

-- ── 1. Cubic Bezier Solver ───────────────────────────────────────────────────
function Curves.bezierParameter(alpha: number, x1: number, x2: number): number
	if alpha <= 0 then return 0 end
	if alpha >= 1 then return 1 end

	x1 = math.clamp(x1, 0, 1)
	x2 = math.clamp(x2, 0, 1)

	local lo, hi, u = 0, 1, alpha
	for _ = 1, 32 do
		local v = 1 - u
		local x = 3 * v * v * u * x1 + 3 * v * u * u * x2 + u * u * u
		local delta = x - alpha
		if math.abs(delta) <= 1e-7 then
			break
		end

		if delta < 0 then
			lo = u
		else
			hi = u
		end

		local deriv = 3 * v * v * x1 + 6 * v * u * (x2 - x1) + 3 * u * u * (1 - x2)
		local cand = deriv > 1e-7 and (u - delta / deriv) or -1
		u = (cand > lo and cand < hi) and cand or (lo + hi) * 0.5
	end

	return u
end

function Curves.cubic(a: number, b: number, c: number, d: number, u: number): number
	local v = 1 - u
	return a * (v * v * v) + b * (3 * v * v * u) + c * (3 * v * u * u) + d * (u * u * u)
end

function Curves.bezierAlpha(t: number, x1: number?, y1: number?, x2: number?, y2: number?): number
	if t <= 0 then return 0 end
	if t >= 1 then return 1 end

	local px1 = x1 or 0.42
	local py1 = y1 or 0.0
	local px2 = x2 or 0.58
	local py2 = y2 or 1.0

	local u = Curves.bezierParameter(t, px1, px2)
	return Curves.cubic(0, py1, py2, 1, u)
end

-- ── 2. Standard Easing Functions ─────────────────────────────────────────────
local EasingTable: { [string]: (t: number) -> number } = {
	Linear = function(t) return t end,

	SineIn = function(t) return 1 - math.cos(t * HALF_PI) end,
	SineOut = function(t) return math.sin(t * HALF_PI) end,
	SineInOut = function(t) return -(math.cos(PI * t) - 1) * 0.5 end,

	QuadIn = function(t) return t * t end,
	QuadOut = function(t) return t * (2 - t) end,
	QuadInOut = function(t) return t < 0.5 and (2 * t * t) or (-1 + (4 - 2 * t) * t) end,

	CubicIn = function(t) return t * t * t end,
	CubicOut = function(t) local f = t - 1 return f * f * f + 1 end,
	CubicInOut = function(t) return t < 0.5 and (4 * t * t * t) or ((t - 1) * (2 * t - 2) * (2 * t - 2) + 1) end,

	QuartIn = function(t) return t * t * t * t end,
	QuartOut = function(t) local f = t - 1 return 1 - f * f * f * f end,
	QuartInOut = function(t) local f = t - 1 return t < 0.5 and (8 * t * t * t * t) or (1 - 8 * f * f * f * f) end,

	ExpoIn = function(t) return t == 0 and 0 or math.pow(2, 10 * (t - 1)) end,
	ExpoOut = function(t) return t == 1 and 1 or (1 - math.pow(2, -10 * t)) end,
	ExpoInOut = function(t)
		if t == 0 then return 0 end
		if t == 1 then return 1 end
		if t < 0.5 then return math.pow(2, 20 * t - 10) * 0.5 end
		return (2 - math.pow(2, -20 * t + 10)) * 0.5
	end,

	BackIn = function(t) local s = DEFAULT_OVERSHOOT return t * t * ((s + 1) * t - s) end,
	BackOut = function(t) local s = DEFAULT_OVERSHOOT local f = t - 1 return f * f * ((s + 1) * f + s) + 1 end,
	BackInOut = function(t)
		local s = DEFAULT_OVERSHOOT * 1.525
		local f = t * 2
		if f < 1 then return 0.5 * (f * f * ((s + 1) * f - s)) end
		f = f - 2
		return 0.5 * (f * f * ((s + 1) * f + s) + 2)
	end,

	BounceOut = function(t)
		if t < (1 / 2.75) then
			return 7.5625 * t * t
		elseif t < (2 / 2.75) then
			local f = t - (1.5 / 2.75)
			return 7.5625 * f * f + 0.75
		elseif t < (2.5 / 2.75) then
			local f = t - (2.25 / 2.75)
			return 7.5625 * f * f + 0.9375
		else
			local f = t - (2.625 / 2.75)
			return 7.5625 * f * f + 0.984375
		end
	end,
	BounceIn = function(t)
		local fn = nil
		-- forward declaration
		return 1 - (function(x)
			if x < (1 / 2.75) then return 7.5625 * x * x
			elseif x < (2 / 2.75) then local f = x - (1.5 / 2.75) return 7.5625 * f * f + 0.75
			elseif x < (2.5 / 2.75) then local f = x - (2.25 / 2.75) return 7.5625 * f * f + 0.9375
			else local f = x - (2.625 / 2.75) return 7.5625 * f * f + 0.984375 end
		end)(1 - t)
	end,
	BounceInOut = function(t)
		local bounceOut = function(x: number): number
			if x < (1 / 2.75) then return 7.5625 * x * x
			elseif x < (2 / 2.75) then local f = x - (1.5 / 2.75) return 7.5625 * f * f + 0.75
			elseif x < (2.5 / 2.75) then local f = x - (2.25 / 2.75) return 7.5625 * f * f + 0.9375
			else local f = x - (2.625 / 2.75) return 7.5625 * f * f + 0.984375 end
		end
		if t < 0.5 then
			return (1 - bounceOut(1 - t * 2)) * 0.5
		end
		return bounceOut(t * 2 - 1) * 0.5 + 0.5
	end,

	ElasticOut = function(t)
		if t == 0 then return 0 end
		if t == 1 then return 1 end
		local p = 0.3
		local s = p / 4
		return math.pow(2, -10 * t) * math.sin((t - s) * TAU / p) + 1
	end,
	ElasticIn = function(t)
		if t == 0 then return 0 end
		if t == 1 then return 1 end
		local p = 0.3
		local s = p / 4
		local f = t - 1
		return -(math.pow(2, 10 * f) * math.sin((f - s) * TAU / p))
	end,
	ElasticInOut = function(t)
		if t == 0 then return 0 end
		if t == 1 then return 1 end
		local p = 0.3 * 1.5
		local s = p / 4
		local f = t * 2 - 1
		if f < 0 then
			return -0.5 * (math.pow(2, 10 * f) * math.sin((f - s) * TAU / p))
		end
		return math.pow(2, -10 * f) * math.sin((f - s) * TAU / p) * 0.5 + 1
	end
}

function Curves.evaluate(easingName: string?, t: number): number
	t = math.clamp(t, 0, 1)
	local name = easingName or "QuadInOut"
	local fn = EasingTable[name]
	if fn then
		return fn(t)
	end
	return t
end

-- ── 3. Quaternion SLERP (Spherical Linear Interpolation) ──────────────────────
-- Representasi Quaternion: { x, y, z, w }
type Quat = { x: number, y: number, z: number, w: number }

local function cframeToQuat(cf: CFrame): (Vector3, Quat)
	local _, _, _, m00, m01, m02, m10, m11, m12, m20, m21, m22 = cf:GetComponents()
	local trace = m00 + m11 + m22
	local q: Quat
	if trace > 0 then
		local s = math.sqrt(trace + 1) * 2
		q = { x = (m21 - m12) / s, y = (m02 - m20) / s, z = (m10 - m01) / s, w = 0.25 * s }
	elseif (m00 > m11) and (m00 > m22) then
		local s = math.sqrt(1 + m00 - m11 - m22) * 2
		q = { x = 0.25 * s, y = (m01 + m10) / s, z = (m02 + m20) / s, w = (m21 - m12) / s }
	elseif m11 > m22 then
		local s = math.sqrt(1 + m11 - m00 - m22) * 2
		q = { x = (m01 + m10) / s, y = 0.25 * s, z = (m12 + m21) / s, w = (m02 - m20) / s }
	else
		local s = math.sqrt(1 + m22 - m00 - m11) * 2
		q = { x = (m02 + m20) / s, y = (m12 + m21) / s, z = 0.25 * s, w = (m10 - m01) / s }
	end
	return cf.Position, q
end

local function quatToCFrame(pos: Vector3, q: Quat): CFrame
	local x, y, z, w = q.x, q.y, q.z, q.w
	local xx, yy, zz = x * x, y * y, z * z
	local xy, xz, yz = x * y, x * z, y * z
	local wx, wy, wz = w * x, w * y, w * z

	return CFrame.new(
		pos.X, pos.Y, pos.Z,
		1 - 2 * (yy + zz), 2 * (xy - wz), 2 * (xz + wy),
		2 * (xy + wz), 1 - 2 * (xx + zz), 2 * (yz - wx),
		2 * (xz - wy), 2 * (yz + wx), 1 - 2 * (xx + yy)
	)
end

function Curves.slerp(cfA: CFrame, cfB: CFrame, alpha: number): CFrame
	if alpha <= 0 then return cfA end
	if alpha >= 1 then return cfB end

	local posA, qA = cframeToQuat(cfA)
	local posB, qB = cframeToQuat(cfB)

	local cosHalfTheta = qA.x * qB.x + qA.y * qB.y + qA.z * qB.z + qA.w * qB.w
	if cosHalfTheta < 0 then
		qB = { x = -qB.x, y = -qB.y, z = -qB.z, w = -qB.w }
		cosHalfTheta = -cosHalfTheta
	end

	local qResult: Quat
	if math.abs(cosHalfTheta) >= 1 then
		qResult = qA
	else
		local halfTheta = math.acos(math.clamp(cosHalfTheta, -1, 1))
		local sinHalfTheta = math.sqrt(1 - cosHalfTheta * cosHalfTheta)
		if math.abs(sinHalfTheta) < 1e-4 then
			qResult = {
				x = qA.x * (1 - alpha) + qB.x * alpha,
				y = qA.y * (1 - alpha) + qB.y * alpha,
				z = qA.z * (1 - alpha) + qB.z * alpha,
				w = qA.w * (1 - alpha) + qB.w * alpha,
			}
		else
			local ratioA = math.sin((1 - alpha) * halfTheta) / sinHalfTheta
			local ratioB = math.sin(alpha * halfTheta) / sinHalfTheta
			qResult = {
				x = qA.x * ratioA + qB.x * ratioB,
				y = qA.y * ratioA + qB.y * ratioB,
				z = qA.z * ratioA + qB.z * ratioB,
				w = qA.w * ratioA + qB.w * ratioB,
			}
		end
	end

	local interpPos = posA:Lerp(posB, alpha)
	return quatToCFrame(interpPos, qResult)
end

return Curves

