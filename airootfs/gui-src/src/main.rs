slint::include_modules!();

use std::process::{Command, Stdio};
use std::io::{BufRead, BufReader};
use std::thread;
use std::rc::Rc;
use slint::{ModelRc, SharedString, VecModel};

fn main() -> Result<(), slint::PlatformError> {
    let ui = InstallerWindow::new()?;
    
    // ==========================================
    // HARDWARE SCANNER: Fetch real disks via lsblk
    // ==========================================
    let output = Command::new("lsblk")
        .arg("-nd")
        .arg("-o")
        .arg("NAME,SIZE")
        .output()
        .expect("Failed to execute lsblk");

    let mut disks: Vec<SharedString> = Vec::new();
    if output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        for line in stdout.lines() {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 2 {
                let name = parts[0];
                let size = parts[1];
                // Only include block devices (SATA, NVMe, Virtual Drives)
                if name.starts_with("sd") || name.starts_with("nvme") || name.starts_with("vd") {
                    let display_str = format!("/dev/{} - {}", name, size);
                    disks.push(display_str.into());
                }
            }
        }
    }

    if disks.is_empty() {
        disks.push("No drives found!".into());
    }

    let disks_model = Rc::new(VecModel::from(disks));
    ui.set_available_disks(ModelRc::from(disks_model.clone()));

    // ==========================================
    // DASHBOARD LOGIC: Launch Terminal
    // ==========================================
    ui.global::<InstallerLogic>().on_launch_terminal(move || {
        thread::spawn(|| {
            Command::new("kitty")
                .spawn()
                .expect("Failed to launch terminal");
        });
    });

    // ==========================================
    // DASHBOARD LOGIC: Update System
    // ==========================================
    ui.global::<InstallerLogic>().on_update_system(move || {
        thread::spawn(|| {
            Command::new("kitty")
                .arg("-e")
                .arg("sudo")
                .arg("pacman")
                .arg("-Syu")
                .spawn()
                .expect("Failed to launch update process");
        });
    });

    // ==========================================
    // INSTALLER LOGIC: Execute Bash Backend
    // ==========================================
    let ui_handle = ui.as_weak();
    
    // The callback now expects all 11 configuration points from the GUI
    ui.global::<InstallerLogic>().on_start_install(move |
        target_disk, install_mode, part_strategy, 
        hostname, username, password, root_password, 
        browser, perf, selected_de, selected_boot
    | {
        let ui_handle = ui_handle.clone();
        
        // --- DATA CLEANUP ---
        let pure_disk_path = target_disk.as_str().split_whitespace().next().unwrap_or("").to_string();
        let mode_num = install_mode.as_str().split('.').next().unwrap_or("2").to_string();
        let part_num = part_strategy.as_str().split('.').next().unwrap_or("3").to_string();
        
        // Pass account info exactly as typed
        let host_str = hostname.as_str().to_string();
        let user_str = username.as_str().to_string();
        let pass_str = password.as_str().to_string();
        let root_pass_str = root_password.as_str().to_string();
        
        let browser_num = browser.as_str().split('.').next().unwrap_or("1").to_string();
        let perf_char = if perf.as_str().starts_with('Y') { "Y" } else { "N" };
        let de_num = selected_de.as_str().split('.').next().unwrap_or("1").to_string();
        let boot_num = selected_boot.as_str().split('.').next().unwrap_or("1").to_string();
        
        thread::spawn(move || {
            let mut child = Command::new("bash")
                .arg("/usr/local/bin/install.sh") 
                // --- INJECTING THE FULL CONFIGURATION ---
                .env("TARGET_DISK", &pure_disk_path)
                .env("INSTALL_MODE", &mode_num)
                .env("PARTITION_STRATEGY", &part_num)
                .env("GUI_HOSTNAME", &host_str)
                .env("GUI_USERNAME", &user_str)
                .env("GUI_PASSWORD", &pass_str)
                .env("GUI_ROOT_PASSWORD", &root_pass_str)
                .env("BROWSER_CHOICE", &browser_num)
                .env("PERF_CHOICE", &perf_char)
                .env("DE_CHOICE", &de_num)
                .env("BOOT_CHOICE", &boot_num)
                .env("NON_INTERACTIVE", "1") 
                .stdout(Stdio::piped())
                .stderr(Stdio::piped())
                .spawn()
                .expect("Failed to execute Kestrel bash script");

            let stdout = child.stdout.take().expect("Failed to capture stdout");
            let reader = BufReader::new(stdout);

            let mut current_progress: f32 = 0.0;

            for line in reader.lines() {
                if let Ok(output) = line {
                    // Update progress based on Bash output keywords
                    if output.contains("Formatting") || output.contains("partition") {
                        current_progress = 0.25;
                    } else if output.contains("pacstrap") || output.contains("Installing") {
                        current_progress = 0.60;
                    } else if output.contains("bootloader") || output.contains("grub") || output.contains("limine") {
                        current_progress = 0.85;
                    }

                    let status_text = output.clone();
                    slint::invoke_from_event_loop({
                        let ui_handle = ui_handle.clone();
                        move || {
                            if let Some(ui) = ui_handle.upgrade() {
                                ui.global::<InstallerLogic>().set_status_text(status_text.into());
                                ui.global::<InstallerLogic>().set_progress(current_progress);
                            }
                        }
                    }).unwrap();
                }
            }
            
            let status = child.wait().expect("Failed to wait on backend process");

            slint::invoke_from_event_loop({
                let ui_handle = ui_handle.clone();
                move || {
                    if let Some(ui) = ui_handle.upgrade() {
                        if status.success() {
                            ui.global::<InstallerLogic>().set_progress(1.0);
                            ui.set_active_step(99); // Moved "Success" screen to an end state number
                        } else {
                            ui.global::<InstallerLogic>().set_status_text("Installation failed! Check console output.".into());
                        }
                    }
                }
            }).unwrap();
        });
    });

    ui.run()
}
