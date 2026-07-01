# Overlay

## Status

- 2026-06-30: Initial spec.

## Domain Definition

- **Interests**: the overlay layer
	- overlay items
	- drag positioning and scaling
	- styling
	- live preview
	- rendering onto media
	- Owns the shared position-editor widget
- **Non-interests**
	- data sourcing (location)
	- capture/burning mechanics (camera reuses the rendered layer)

## Details

### Items

* Each item is independently toggleable. 
* Source data comes from `LocationSnapshot` plus user input (note).
* Each item has a pre-defined position

Supported items:
- map
- QR code 
- address 
* coordinates 
* altitude 
* location accuracy
* compass direction 
* capture time 
* note 
* weather (TODO)
* watermark
* logo / custom image (TODO) — user-supplied, distinct from the app watermark

### Position & scale editor

- The **position and scale editor** is a `Control.custom` widget owned by this domain. 
	- Users can resize and place the overlay by drag-and-drop, just like instagram stickers
	- The same widget is used on the Main screen and in Settings → Overlay.

### Rendering

- `OverlayRendering` seam: given a `LocationSnapshot` + current overlay settings,
  produces the overlay layer.
- Reused three ways: live on Main, burned into captures by camera, and as the
  settings preview (a `Control.custom`).

### Styling

- font 
- font size 
- text color 
- background color 
- background opacity
- date/time format 
- coordinate format (lat-lon / DMS) 
- unit

## Settings

| key                         | title                               | control                  | default | gate                          |
| --------------------------- | ----------------------------------- | ------------------------ | ------- | ----------------------------- |
| `overlay.enabled`           | Include overlay in photo/video      | toggle                   | on      | free                          |
| `overlay.preview`           | Preview                             | custom                   | —       | free                          |
| `overlay.layout`            | Adjust position                     | custom (position editor) | —       | free                          |
| `overlay.item.*`            | Display items (one toggle per item) | toggle                   | on      | free                          |
| `overlay.item.watermark`    | Watermark                           | toggle                   | on      | **pro** (free cannot disable) |
| `overlay.style.font`        | Font                                | select                   | system  | **pro**                       |
| `overlay.style.size`        | Font size                           | stepper                  | default | **pro**                       |
| `overlay.style.textColor`   | Text color                          | color                    | —       | **pro**                       |
| `overlay.style.bgColor`     | Background color                    | color                    | —       | **pro**                       |
| `overlay.style.bgOpacity`   | Background opacity                  | slider                   | —       | **pro**                       |
| `overlay.style.dateFormat`  | Date/time format                    | select                   | —       | **pro**                       |
| `overlay.style.coordFormat` | Coordinate format                   | select (lat-lon / DMS)   | lat-lon | **pro**                       |
| `overlay.style.unit`        | Unit                                | select                   | metric  | **pro**                       |

## Revision History

- 2026-06-30: Initial overlay spec.
