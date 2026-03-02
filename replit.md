# GYMACK - ASD Math Tutoring App

## Overview
GYMACK is a Flutter-based mathematics tutoring application targeting children aged 3-10 with Mild to Moderate Autism Spectrum Disorder (ASD). The app teaches 4 core math concepts with highly visual, child-friendly design.

## Tech Stack
- **Framework:** Flutter 3.22.0 (web-server mode)
- **Language:** Dart 3.4.0
- **Key Packages:** google_fonts (Nunito), shared_preferences, intl
- **Platform:** Flutter Web (served via `flutter run -d web-server`)

## Project Structure
```
gymack/                    # Flutter project root
  lib/
    main.dart              # App entry point + routing
    theme.dart             # Colors, typography, theme
    screens/
      landing_screen.dart   # Animated GYMACK landing page
      signup_screen.dart    # Parent signup (email, phone, T&C)
      account_setup_screen.dart  # Password + child profile setup
```

## Workflow
- **Start Flutter**: `cd gymack && flutter run -d web-server --web-port=5000 --web-hostname=0.0.0.0`
- Runs on port 5000, viewable in the webview

## Design
- **Color Palette:** Warm orange primary (#FF7043), Teal secondary (#26C6DA), warm white background (#FFF8F0)
- **Typography:** Nunito (rounded, child-friendly)
- **Design principles:** Calm, structured, ASD-friendly - clear layouts, high contrast, minimal clutter

## Screens Implemented
1. **Landing Screen** - Animated GYMACK logo with floating geometric shapes, Create Account + Login buttons
2. **Sign Up Screen** - Parent email, phone number, Terms & Conditions and Privacy Policy checkboxes
3. **Account Setup Screen** - Password creation with strength indicator, child name + DOB with age validation

## Planned Math Modules (Next Phase)
1. Counting - Visual counting with objects
2. Shape Identification - Interactive shape recognition
3. Addition & Subtraction - Visual number operations
4. Multiplication & Division - Visual grouping concepts
