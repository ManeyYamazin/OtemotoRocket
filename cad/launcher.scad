// ====================================================================
// OtemotoRocket - Launcher Cap & Nozzle
// ====================================================================
// Spec: PET Bottle (PCO-1881) to Chopstick Sleeve Flatfish/Lens Nozzle
// Pure OpenSCAD, Single-file Self-contained, Support-free 3D printing
// ====================================================================

// --- Rendering Quality ---
$fn = 60; // Smooth curves

// --- Main Dimensions ---
nozzle_w        = 15.0;  // Nozzle outer width (15.0mm for effortless low-friction launch)
nozzle_t        = 4.5;   // Nozzle outer thickness (minor axis, mm)
wall_thickness  = 1.2;   // Wall thickness (mm, 3 perimeters with 0.4mm nozzle)

straight_height = 130.0; // Effective straight nozzle height (full 130mm guide)
taper_height    = 15.0;  // Root transition/funnel height (mm)
cap_height      = 15.0;  // Screw cap height (mm)
tip_fillet_r    = 1.0;   // Tip fillet radius (reverted to proven R1.0mm smooth fillet)

// --- Cap Parameters (PCO-1881 standard, verified on physical bottles) ---
cap_od          = 33.0;  // Cap outer diameter (with grip ribs)
cap_root_id     = 28.2;  // Cap inner root diameter (mm, with 3D print clearance)
thread_pitch    = 2.70;  // PCO-1881 thread pitch (mm)
thread_turns    = 2.3;   // Thread turns
thread_depth    = 1.15;  // Thread ridge height / protrusion (mm)
bottle_lip_id   = 21.5;  // Inner funnel opening diameter at cap ceiling (mm)

// --- Derived Inner Dimensions ---
nozzle_in_w = nozzle_w - 2 * wall_thickness; // 12.6 mm
nozzle_in_t = nozzle_t - 2 * wall_thickness; // 2.1 mm

// --- 2D Lens Profile Module ---
module lens_2d(w, t) {
    h = t / 2;
    a = w / 2;
    r = (a*a + h*h) / (2 * h);
    offset_y = r - h;
    intersection() {
        translate([0, -offset_y]) circle(r = r);
        translate([0,  offset_y]) circle(r = r);
    }
}

// --- Cap Internal Thread (PCO-1881 Spiral Ridge) ---
module pco1881_female_thread() {
    steps_per_turn = 24;
    total_steps = round(thread_turns * steps_per_turn);
    r_root = cap_root_id / 2;
    w_base = 1.6;
    w_tip  = 0.6;
    
    module profile(d, wt) {
        linear_extrude(height = 0.05, center = true)
            polygon([
                [0.1, -w_base/2],
                [-d, -wt/2],
                [-d,  wt/2],
                [0.1,  w_base/2]
            ]);
    }
    
    for (i = [0 : total_steps - 1]) {
        z1 = i * thread_pitch / steps_per_turn;
        z2 = (i + 1) * thread_pitch / steps_per_turn;
        a1 = i * 360 / steps_per_turn;
        a2 = (i + 1) * 360 / steps_per_turn;
        
        fade_steps = 6;
        f1 = (i < fade_steps) ? (i / fade_steps) : ((i > total_steps - fade_steps) ? (total_steps - i) / fade_steps : 1.0);
        f2 = ((i+1) < fade_steps) ? ((i+1) / fade_steps) : (((i+1) > total_steps - fade_steps) ? (total_steps - (i+1)) / fade_steps : 1.0);
        d1 = max(0.1, thread_depth * f1);
        d2 = max(0.1, thread_depth * f2);
        wt1 = max(0.2, w_tip * f1);
        wt2 = max(0.2, w_tip * f2);
        
        hull() {
            rotate([0, 0, a1])
                translate([r_root, 0, z1])
                    rotate([90, 0, 0])
                        profile(d1, wt1);
            rotate([0, 0, a2])
                translate([r_root, 0, z2])
                    rotate([90, 0, 0])
                        profile(d2, wt2);
        }
    }
}

// --- Outer Cap Body with Grip Ribs ---
module cap_outer() {
    cylinder(d = cap_od, h = cap_height);
    // Vertical grip ribs
    num_ribs = 24;
    for (i = [0 : num_ribs - 1]) {
        rotate([0, 0, i * 360 / num_ribs])
            translate([cap_od / 2, 0, 0])
                cylinder(r = 0.8, h = cap_height, $fn = 16);
    }
}

// --- Complete Launcher Model ---
module launcher_cap_nozzle() {
    total_h     = cap_height + taper_height + straight_height;
    z_cap_top   = cap_height;
    z_taper_top = cap_height + taper_height;
    
    difference() {
        // === OUTER SOLID ===
        union() {
            // 1. Cap Outer
            cap_outer();
            
            // 2. Root Taper Section (Outer transition)
            hull() {
                translate([0, 0, z_cap_top - 0.1])
                    cylinder(d = 26.0, h = 0.2); // Smooth neck base
                translate([0, 0, z_taper_top])
                    linear_extrude(height = 0.1)
                        lens_2d(nozzle_w, nozzle_t);
            }
            
            // 3. Straight Nozzle Body (130mm full guide)
            translate([0, 0, z_taper_top])
                linear_extrude(height = straight_height - tip_fillet_r)
                    lens_2d(nozzle_w, nozzle_t);
            
            // 4. Tip Fillet (Proven smooth rounded tip transition)
            hull() {
                translate([0, 0, total_h - tip_fillet_r])
                    linear_extrude(height = 0.05)
                        lens_2d(nozzle_w, nozzle_t);
                translate([0, 0, total_h])
                    linear_extrude(height = 0.05)
                        lens_2d(nozzle_w - 2 * tip_fillet_r, nozzle_t - 2 * tip_fillet_r);
            }
        }
        
        // === INNER HOLLOW (Air Path) ===
        union() {
            // 1. Cap Internal Cavity (threaded receiver)
            translate([0, 0, -0.1])
                cylinder(d = cap_root_id, h = cap_height - 2.5 + 0.1);
            
            // 2. Bottle Lip Chamfer Stop
            translate([0, 0, cap_height - 2.5])
                cylinder(d1 = cap_root_id, d2 = bottle_lip_id, h = 2.0);
            
            // 3. Funnel (Transition from bottle lip to nozzle slit)
            hull() {
                translate([0, 0, cap_height - 0.6])
                    cylinder(d = bottle_lip_id, h = 0.2);
                translate([0, 0, z_taper_top])
                    linear_extrude(height = 0.1)
                        lens_2d(nozzle_in_w, nozzle_in_t);
            }
            
            // 4. Straight Nozzle Internal Path (All the way out through tip)
            translate([0, 0, z_taper_top - 0.1])
                linear_extrude(height = straight_height + 1.0)
                    lens_2d(nozzle_in_w, nozzle_in_t);
        }
    }
    
    // Add Internal Thread Ridge inside Cap Cavity
    translate([0, 0, 2.0])
        pco1881_female_thread();
}

// Generate part
launcher_cap_nozzle();
