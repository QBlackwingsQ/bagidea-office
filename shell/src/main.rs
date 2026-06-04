#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]
// BagIdea AI Agents Office — native overlay shell.
//   • CHAT HEAD: a true circular always-on-top launcher (window region clip,
//     Messenger style) showing the brand icon — drag anywhere, click toggles.
//   • OVERLAY: frameless, rounded, custom-chromed web UI. Hiding ≠ closing;
//     the chat head always brings it back and can never be covered.

use tao::{
    dpi::{LogicalPosition, LogicalSize},
    event::{Event, WindowEvent},
    event_loop::{ControlFlow, EventLoopBuilder},
    platform::windows::{WindowBuilderExtWindows, WindowExtWindows},
    window::{Icon, Window, WindowBuilder},
};
use windows_sys::Win32::Graphics::Gdi::{CreateEllipticRgn, CreateRoundRectRgn, SetWindowRgn};
use wry::WebViewBuilder;

#[derive(Debug)]
enum UserEvent {
    Toggle,
    DragOrb,
    DragOverlay,
    HideOverlay,
    MiniToggle,
    Quit,
}

const ORB_SIZE: f64 = 72.0;
const FULL: (f64, f64) = (560.0, 700.0);
const MINI: (f64, f64) = (390.0, 430.0);

const ORB_HTML: &str = r#"<!doctype html>
<html><body style="margin:0;overflow:hidden;background:#0a111d;user-select:none;-webkit-user-select:none;cursor:pointer">
<img id="ic" src="http://127.0.0.1:8787/brand/logo_ico_cute.png" draggable="false"
     style="width:100vw;height:100vh;object-fit:cover"
     onerror="document.body.style.background='radial-gradient(circle at 32% 28%,#2a78d8,#0b1422)'">
<script>
  // Messenger chat-head feel: press-and-move drags, clean click toggles.
  let downAt = null, dragged = false;
  document.body.addEventListener('mousedown', (e) => {
    if (e.button === 0) { downAt = [e.screenX, e.screenY]; dragged = false; }
  });
  document.body.addEventListener('mousemove', (e) => {
    if (downAt && !dragged &&
        Math.hypot(e.screenX - downAt[0], e.screenY - downAt[1]) > 6) {
      dragged = true;
      window.ipc.postMessage('drag-orb');
    }
  });
  document.body.addEventListener('mouseup', () => { downAt = null; });
  document.body.addEventListener('click', () => {
    if (!dragged) window.ipc.postMessage('toggle');
    dragged = false;
  });
  document.body.addEventListener('contextmenu', (e) => {
    e.preventDefault();
    window.ipc.postMessage('quit');
  });
</script>
</body></html>"#;

fn round_region(window: &Window, w: f64, h: f64, radius: f64) {
    let sf = window.scale_factor();
    unsafe {
        let rgn = CreateRoundRectRgn(
            0, 0,
            (w * sf) as i32 + 1, (h * sf) as i32 + 1,
            (radius * sf) as i32, (radius * sf) as i32,
        );
        SetWindowRgn(window.hwnd() as _, rgn, 1);
    }
}

fn circle_region(window: &Window, d: f64) {
    let sf = window.scale_factor();
    unsafe {
        let rgn = CreateEllipticRgn(0, 0, (d * sf) as i32 + 1, (d * sf) as i32 + 1);
        SetWindowRgn(window.hwnd() as _, rgn, 1);
    }
}

fn app_icon() -> Option<Icon> {
    let img = image::load_from_memory(include_bytes!("../../godot/assets/brand/logo_ico_cute.png"))
        .ok()?
        .into_rgba8();
    let (w, h) = img.dimensions();
    Icon::from_rgba(img.into_raw(), w, h).ok()
}

fn main() {
    let event_loop = EventLoopBuilder::<UserEvent>::with_user_event().build();
    let proxy = event_loop.create_proxy();

    // Work out sane default positions from the primary monitor: the chat
    // head sits inset by one orb-size from the right edge, never sunk.
    let (screen_w, _screen_h, sf) = event_loop
        .primary_monitor()
        .map(|m| (m.size().width as f64, m.size().height as f64, m.scale_factor()))
        .unwrap_or((1920.0, 1080.0, 1.0));
    let logical_w = screen_w / sf;
    let orb_x = logical_w - ORB_SIZE * 2.0;
    let orb_y = ORB_SIZE;
    let overlay_x = (logical_w - FULL.0 - ORB_SIZE * 2.2).max(20.0);
    let overlay_y = 90.0;

    // ---- overlay window: frameless + rounded, custom chrome lives in HTML.
    // Created VISIBLE but parked off-screen: WebView2 never fully wakes on a
    // window born hidden (scripts stay frozen), so "hidden" = parked far away.
    const PARK: (f64, f64) = (-9000.0, 100.0);
    let overlay = WindowBuilder::new()
        .with_title("BagIdea Office")
        .with_inner_size(LogicalSize::new(FULL.0, FULL.1))
        .with_position(LogicalPosition::new(PARK.0, PARK.1))
        .with_decorations(false)
        .with_resizable(false)
        .with_always_on_top(true)
        .with_window_icon(app_icon())
        .build(&event_loop)
        .expect("overlay window");
    round_region(&overlay, FULL.0, FULL.1, 18.0);
    let overlay_id = overlay.id();
    let p_overlay = proxy.clone();
    let overlay_view = WebViewBuilder::new()
        .with_url("http://127.0.0.1:8787/")
        .with_devtools(true)
        .with_ipc_handler(move |req| {
            let _ = match req.body().as_str() {
                "drag-overlay" => p_overlay.send_event(UserEvent::DragOverlay),
                "hide" => p_overlay.send_event(UserEvent::HideOverlay),
                "mini" => p_overlay.send_event(UserEvent::MiniToggle),
                _ => Ok(()),
            };
        })
        .build(&overlay)
        .expect("overlay webview");

    // ---- chat head: a genuinely circular window.
    let orb = WindowBuilder::new()
        .with_title("BagIdea")
        .with_inner_size(LogicalSize::new(ORB_SIZE, ORB_SIZE))
        .with_position(LogicalPosition::new(orb_x, orb_y))
        .with_decorations(false)
        .with_resizable(false)
        .with_always_on_top(true)
        .with_skip_taskbar(true)
        .with_window_icon(app_icon())
        .build(&event_loop)
        .expect("orb window");
    circle_region(&orb, ORB_SIZE);
    let orb_id = orb.id();
    let p_orb = proxy.clone();
    let _orb_view = WebViewBuilder::new()
        .with_html(ORB_HTML)
        .with_ipc_handler(move |req| {
            let _ = match req.body().as_str() {
                "toggle" => p_orb.send_event(UserEvent::Toggle),
                "drag-orb" => p_orb.send_event(UserEvent::DragOrb),
                "quit" => p_orb.send_event(UserEvent::Quit),
                _ => Ok(()),
            };
        })
        .build(&orb)
        .expect("orb webview");

    // Among multiple TOPMOST windows, Windows orders by recency — re-assert
    // the chat head whenever the overlay comes forward.
    let raise_orb = |orb: &Window| {
        orb.set_always_on_top(false);
        orb.set_always_on_top(true);
    };

    let mut overlay_visible = false;
    let mut mini = false;
    event_loop.run(move |event, _, control_flow| {
        *control_flow = ControlFlow::Wait;
        match event {
            Event::WindowEvent { window_id, event: WindowEvent::CloseRequested, .. } => {
                if window_id == overlay_id {
                    overlay.set_outer_position(LogicalPosition::new(PARK.0, PARK.1));
                    overlay_visible = false;
                } else if window_id == orb_id {
                    *control_flow = ControlFlow::Exit;
                }
            }
            Event::WindowEvent { window_id, event: WindowEvent::Focused(true), .. } => {
                if window_id == overlay_id {
                    raise_orb(&orb);
                }
            }
            Event::UserEvent(ue) => match ue {
                UserEvent::Toggle => {
                    overlay_visible = !overlay_visible;
                    if overlay_visible {
                        overlay.set_outer_position(LogicalPosition::new(overlay_x, overlay_y));
                        overlay.set_focus();
                        raise_orb(&orb);
                        let _ = &overlay_view;
                    } else {
                        overlay.set_outer_position(LogicalPosition::new(PARK.0, PARK.1));
                    }
                }
                UserEvent::HideOverlay => {
                    overlay.set_outer_position(LogicalPosition::new(PARK.0, PARK.1));
                    overlay_visible = false;
                }
                UserEvent::MiniToggle => {
                    mini = !mini;
                    let (w, h) = if mini { MINI } else { FULL };
                    overlay.set_inner_size(LogicalSize::new(w, h));
                    round_region(&overlay, w, h, 18.0);
                    raise_orb(&orb);
                }
                UserEvent::DragOrb => { let _ = orb.drag_window(); }
                UserEvent::DragOverlay => { let _ = overlay.drag_window(); }
                UserEvent::Quit => { *control_flow = ControlFlow::Exit; }
            },
            _ => {}
        }
    });
}
