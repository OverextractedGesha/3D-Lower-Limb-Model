# Knee Extension Biomechanical Simulation (Lazarus & Delphi)

Cross-platform Object Pascal simulation of a 3-joint lower-limb Lagrangian model and 1-DOF Functional Electrical Stimulation (FES) knee extension dynamics.

## Project Structure

- `shared/` — Pure Object Pascal computation engine (`{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}`, zero external math/GUI dependencies):
  - `uBiomechCore.pas` — Single consolidated logic unit containing types/constants, from-scratch math helpers (`Clamp`, `SafeExp`, `SafeTanh`), Winter (2009) anthropometry, 3-DOF planar Euler-Lagrange dynamics ($M$, $C$, $G$, Riener & Edrich 1999 passive torques), and `TKneeSimEngine` (Hill muscle model + RK4 solver).
- `tests/` — Headless FPC unit test suite (`test_biomech.lpr`).
- `lazarus_app/` — Linux Lazarus LCL + `TAChart` GUI application (`KneeExtensionLaz.lpi`).
- `delphi_app/` — Windows Modern Delphi VCL + `VCLTee.Chart` GUI application (`KneeExtensionDelphi.dproj`).

## Biomechanical Equations Summary

### 1. Winter (2009) Anthropometry ($BW$ in kg, $BH$ in m)
- **Thigh**: $L_1 = 0.245\,BH$, $M_1 = 0.100\,BW$, $A_1 = 0.433\,L_1$, $I_1 = M_1 (0.323\,L_1)^2$
- **Shank**: $L_2 = 0.246\,BH$, $M_2 = 0.0465\,BW$, $A_2 = 0.433\,L_2$, $I_2 = M_2 (0.302\,L_2)^2$
- **Foot**: $L_3 = 0.152\,BH$, $M_3 = 0.0145\,BW$, $A_3 = 0.500\,L_3$, $I_3 = M_3 (0.475\,L_3)^2$
- **Seated Knee Inertia**: $I_{\text{knee}} = I_2 + M_2 A_2^2 + I_3 + M_3(L_2^2 + A_3^2)$

### 2. 3-DOF Lagrangian Matrix Form
$$M(\theta)\ddot{\theta} + C(\theta,\dot{\theta})\dot{\theta} + G(\theta) = \tau_{\text{act}} + \tau_{\text{passive}}(\theta,\dot{\theta})$$
Evaluated across Hip ($\tau_{P3}$), Knee ($\tau_{P2}$), and Ankle ($\tau_{P1}$) in `EvaluateLagrange3DOF`.

### 3. 1-DOF FES Knee Extension Model
- **Angle Convention**: $\theta = \pi/2\text{ rad}$ ($90^\circ$) vertical hanging flexion; $\theta = 0\text{ rad}$ ($0^\circ$) full horizontal extension.
- **Recruitment Curve**: $u = 0.5\tanh(15.0\,(s_1 - 0.5)) + 0.5$
- **Activation Dynamics** ($T_r = 0.100\text{ s}$, $T_f = 0.150\text{ s}$):
  $$\dot{a} = \begin{cases} (u - a)/T_r, & u > a \\ (u - a)/T_f, & u \le a \end{cases}$$
- **Hill Muscle Mechanics**:
  - $L(\theta) = L_{\text{opt}} + R_{\text{ma}}(\theta - \theta_{\text{opt}})$, $V = R_{\text{ma}}\dot{\theta}$
  - $f(l) = \exp\!\left(-\left(\frac{L/L_{\text{opt}} - 1}{0.56}\right)^2\right)$
  - $f(v)$ bounded in $[0, 1.8]$ (concentric Hill curve for $v \le 0$, eccentric saturation for $v > 0$)
  - $F_m = a\,F_{\max}\,f(l)\,f(v)$, $\tau_{\text{mus}} = R_{\text{ma}} F_m$
- **Equation of Motion**:
  $$\ddot{\theta} = \frac{-\tau_{\text{mus}} + \tau_{\text{grav}}(\theta) + \tau_{\text{elast}}(\theta) + \tau_{\text{damp}}(\dot{\theta})}{I_{\text{knee}}}$$

## Build & Run

### Unit Tests (Linux / FPC)
```bash
fpc -Mdelphi -Fu./shared tests/test_biomech.lpr -o./tests/test_biomech
./tests/test_biomech
```

### Lazarus GUI App (Linux)
Requires Lazarus with `TAChartLazarusPkg` and Qt6 (`libQt6Pas`) or `--ws=gtk2` if GTK2 dev libraries are installed:
```bash
lazbuild lazarus_app/KneeExtensionLaz.lpi
./lazarus_app/KneeExtensionLaz
```

### Delphi GUI App (Windows)
1. Open `delphi_app/KneeExtensionDelphi.dproj` in RAD Studio / Delphi (10.x, 11, or 12).
2. Ensure `Win32` or `Win64` target is selected with TeeChart (`VCLTee`) enabled.
3. Build (`Ctrl+F9`) and Run (`F9`).
