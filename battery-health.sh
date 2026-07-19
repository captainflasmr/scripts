#!/bin/bash
# battery-health.sh - report battery status, wear, and expected runtime

set -e

BAT_PATH="/sys/class/power_supply/BAT0"

# ---- helper ----
fmt() { printf '%s\n' "$1"; }

# ---- sysfs reads ----
charge_full=$(cat "$BAT_PATH/charge_full")
charge_full_design=$(cat "$BAT_PATH/charge_full_design")
charge_now=$(cat "$BAT_PATH/charge_now")
current_now=$(cat "$BAT_PATH/current_now")
voltage_now=$(cat "$BAT_PATH/voltage_now")
status=$(cat "$BAT_PATH/status")
capacity=$(cat "$BAT_PATH/capacity")
capacity_level=$(cat "$BAT_PATH/capacity_level")
temp=$(cat "$BAT_PATH/temp" 2>/dev/null || echo "N/A")
cycle_count=$(cat "$BAT_PATH/cycle_count" 2>/dev/null || echo "N/A")
health=$(cat "$BAT_PATH/health" 2>/dev/null || echo "Unknown")
model_name=$(cat "$BAT_PATH/model_name" 2>/dev/null || echo "Unknown")
manufacturer=$(cat "$BAT_PATH/manufacturer" 2>/dev/null || echo "Unknown")

# ---- derived values (integer math with perc mille for 1 decimal) ----
pct_full_pm=$(( charge_full * 1000 / charge_full_design ))  # per mille
pct_full=$(( pct_full_pm / 10 ))
pct_full_dec=$(( pct_full_pm % 10 ))
wear_pm=$(( 1000 - pct_full_pm ))
wear=$(( wear_pm / 10 ))
wear_dec=$(( wear_pm % 10 ))

# energy in milliWatt-hours (µAh * µV / 10^9 = mWh)
energy_full_mwh=$(( charge_full * voltage_now / 1000000000 ))
energy_full_design_mwh=$(( charge_full_design * voltage_now / 1000000000 ))
energy_now_mwh=$(( charge_now * voltage_now / 1000000000 ))

if [ "$temp" != "N/A" ]; then
    temp_c=$(( temp / 10 ))
    temp_c_dec=$(( temp % 10 ))
    temp_display="${temp_c}.${temp_c_dec}°C"
else
    temp_display="N/A"
fi

# ---- power / time estimates ----
power_mw=0
if [ "$current_now" -gt 0 ] 2>/dev/null; then
    power_mw=$(( voltage_now * current_now / 1000000000 ))
fi

power_w=$(( power_mw / 1000 ))
power_w_dec=$(( power_mw % 1000 / 100 ))

if [[ "$status" == "Discharging" ]] && [ "$current_now" -gt 0 ]; then
    hours_left=$(( charge_now / current_now ))
    mins_left=$(( charge_now * 60 / current_now - hours_left * 60 ))
    hours_display="${hours_left}h ${mins_left}m"
else
    hours_display="N/A (charging / idle)"
fi

# ---- output ----
fmt "=============================================="
fmt "  Battery Health Report"
fmt "=============================================="
fmt "  Model:       $manufacturer $model_name"
fmt "  Status:      $status ($capacity%)"
fmt "  Capacity:    $capacity_level"
fmt "  Health:      $health"
fmt "  Temperature: $temp_display"
if [ "$cycle_count" != "N/A" ]; then
    fmt "  Cycles:      $cycle_count"
fi
fmt ""
fmt " ── Capacities ──"
fmt "  Design full:     $(( charge_full_design / 1000 )) mAh  ($(( energy_full_design_mwh / 1000 )).$(( energy_full_design_mwh % 1000 / 100 )) Wh)"
fmt "  Current full:    $(( charge_full / 1000 )) mAh  ($(( energy_full_mwh / 1000 )).$(( energy_full_mwh % 1000 / 100 )) Wh)"
fmt "  Current charge:  $(( charge_now / 1000 )) mAh  ($(( energy_now_mwh / 1000 )).$(( energy_now_mwh % 1000 / 100 )) Wh)"
fmt ""
fmt " ── Wear ──"
fmt "  Battery worn:    ${wear}.${wear_dec}%"
fmt "  ($(( charge_full_design / 1000 )) → $(( charge_full / 1000 )) mAh)"
fmt ""
fmt " ── Runtime ──"
fmt "  Power draw:  ${power_w}.${power_w_dec} W"
fmt "  Est. remaining:  $hours_display"

# assessment
if [ "$pct_full" -lt 30 ]; then
    severity="CRITICAL"
elif [ "$pct_full" -lt 60 ]; then
    severity="WARNING"
elif [ "$pct_full" -lt 80 ]; then
    severity="FAIR"
else
    severity="GOOD"
fi

fmt ""
fmt " ── Assessment ──"
fmt "  Remaining design capacity: ${pct_full}.${pct_full_dec}% — $severity"

case "$severity" in
    CRITICAL) fmt "  >> Battery is heavily degraded and should be replaced soon." ;;
    WARNING)  fmt "  >> Significant wear. Consider replacing in the near future." ;;
    FAIR)     fmt "  >> Moderate wear — still usable but degraded." ;;
    GOOD)     fmt "  >> Battery is in good condition." ;;
esac

# charge thresholds
if [ -f "$BAT_PATH/charge_control_end_threshold" ]; then
    end=$(cat "$BAT_PATH/charge_control_end_threshold")
    start=$(cat "$BAT_PATH/charge_control_start_threshold")
    fmt ""
    fmt " ── Charge Thresholds ──"
    fmt "  Start: ${start}%  |  Stop: ${end}%"
fi

fmt "=============================================="
