from __future__ import annotations

from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    KeepTogether,
    ListFlowable,
    ListItem,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


BASE_DIR = Path(__file__).resolve().parent.parent
OUTPUT_PATH = BASE_DIR / "docs" / "SafeRoute_Project_Documentation.pdf"


def build_document() -> list:
    styles = getSampleStyleSheet()
    styles.add(
        ParagraphStyle(
            name="TitleAccent",
            parent=styles["Title"],
            fontName="Helvetica-Bold",
            fontSize=22,
            leading=26,
            textColor=colors.HexColor("#13201d"),
            spaceAfter=10,
        )
    )
    styles.add(
        ParagraphStyle(
            name="SectionHeading",
            parent=styles["Heading1"],
            fontName="Helvetica-Bold",
            fontSize=16,
            leading=20,
            textColor=colors.HexColor("#0e7c7b"),
            spaceBefore=12,
            spaceAfter=8,
        )
    )
    styles.add(
        ParagraphStyle(
            name="BodySoft",
            parent=styles["BodyText"],
            fontName="Helvetica",
            fontSize=10.5,
            leading=15,
            textColor=colors.HexColor("#253230"),
            spaceAfter=7,
        )
    )
    styles.add(
        ParagraphStyle(
            name="SmallMeta",
            parent=styles["BodyText"],
            fontName="Helvetica-Bold",
            fontSize=9,
            leading=12,
            textColor=colors.HexColor("#5a6764"),
        )
    )

    story: list = []

    story.append(Paragraph("SafeRoute Project Documentation", styles["TitleAccent"]))
    story.append(
        Paragraph(
            "Introduction, Solution Overview, and Technology Stack",
            styles["Heading2"],
        )
    )
    story.append(
        Paragraph(
            "SafeRoute is a cross-platform transport safety system focused on women commuters in Dar es Salaam. The project combines a Flutter mobile app, a Django/PostgreSQL backend, map and location services, and cloud deployment support for local development, physical devices, and Render-hosted production.",
            styles["BodySoft"],
        )
    )
    story.append(Spacer(1, 8))

    meta_data = [
        [Paragraph("Project", styles["SmallMeta"]), Paragraph("SafeRoute", styles["BodySoft"]), Paragraph("Frontend", styles["SmallMeta"]), Paragraph("Flutter", styles["BodySoft"])],
        [Paragraph("Primary Goal", styles["SmallMeta"]), Paragraph("Safer route planning and route recording", styles["BodySoft"]), Paragraph("Backend", styles["SmallMeta"]), Paragraph("Django + PostgreSQL", styles["BodySoft"])],
    ]
    meta_table = Table(meta_data, colWidths=[28 * mm, 60 * mm, 28 * mm, 60 * mm])
    meta_table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), colors.whitesmoke),
                ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#d9d1c2")),
                ("INNERGRID", (0, 0), (-1, -1), 0.35, colors.HexColor("#d9d1c2")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 8),
                ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                ("TOPPADDING", (0, 0), (-1, -1), 8),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
            ]
        )
    )
    story.append(meta_table)

    sections = [
        (
            "1. Introduction",
            [
                "SafeRoute addresses the real-world problem of transport poverty and safety uncertainty faced by women commuters. The application is designed to help users identify safer travel options, record journeys, and preserve a history of route behavior that can later support safety analysis and operational planning.",
                "The current implementation is not a simple static map app. It is a complete system with user authentication, session handling, route recording, location naming, GPS tracking, database-backed persistence, and an admin dashboard for reviewing recorded travel and managing users.",
            ],
            "Current step in the project: the app is being stabilized around local PostgreSQL and Render deployment behavior, with the backend configured to use environment-driven database settings and the UI starting at the login flow before any dashboard access.",
        ),
        (
            "2. Problem Statement",
            [
                "Safety visibility: commuters often lack a clear view of which routes, stops, or corridors are safer at specific times of day.",
                "Weak historical data: without structured route records, it is difficult to analyze travel behavior, repeated incidents, or risky locations.",
                "Deployment friction: the app must work across local development, Android devices, emulators, and Render-hosted backend environments.",
            ],
            None,
        ),
        (
            "3. Elaborate Solution",
            [
                "SafeRoute solves the problem with a layered architecture. The Flutter client provides an accessible mobile experience for route discovery, recording, and feedback. The Django backend exposes JSON APIs for login, registration, route recording, and route retrieval. PostgreSQL stores users, routes, travel logs, safety reports, and incident records in a durable relational model.",
            ],
            None,
        ),
        (
            "4. Architecture Overview",
            [
                "Frontend: Flutter app with Material 3 theming, localization, Google Maps integration, location tracking, and persistent session storage.",
                "Backend: Django 5.x API using JSON endpoints, CSRF-exempt mobile routes, Google sign-in verification, and a simple admin dashboard.",
                "Database: PostgreSQL with a dedicated saferoute schema and tables for users, routes, logs, locations, and safety reports.",
                "Deployment: local development on Windows, optional Android emulators/devices, and Render deployment for production hosting.",
            ],
            None,
        ),
        (
            "5. Technology Stack",
            [
                "Flutter",
                "Dart 3.10+",
                "Django 5.1+",
                "PostgreSQL 12+",
                "psycopg 3",
                "dj-database-url",
                "google_sign_in",
                "geolocator",
                "google_maps_flutter",
                "http",
                "shared_preferences",
                "gunicorn",
                "Render",
            ],
            None,
        ),
        (
            "6. What Has Been Implemented So Far",
            [
                "Flutter app bootstrapping with splash, auth, and home flow.",
                "Session persistence in shared_preferences.",
                "Backend API client with fallback URLs for local and remote deployment.",
                "Django authentication endpoints for email/password and Google ID token login.",
                "Route recording API that persists named locations and coordinates.",
                "Render deployment configuration and environment variable support.",
                "Admin login root route and trailing-slash-compatible URL patterns.",
                "Database connection troubleshooting and local PostgreSQL verification.",
            ],
            None,
        ),
        (
            "7. Key Design Notes",
            [
                "The app favors environment-driven configuration rather than hard-coded backend hosts.",
                "The backend is structured to support both local development and public deployment.",
                "The project uses a relational database because route history and user relationships are naturally tabular.",
                "The interface is designed for practical mobile use, not only desktop admin access.",
            ],
            None,
        ),
        (
            "8. Current Status and Next Steps",
            [
                "At this step, the project is functionally structured but still being refined around deployment and runtime correctness.",
                "The immediate focus is making sure the backend points at the correct PostgreSQL instance, that the API responds correctly on startup, and that the documentation reflects the real architecture rather than a placeholder summary.",
            ],
            "Recommended next steps: verify the deployed database credentials, confirm the backend health endpoint, and then expand the documentation with screenshots and implementation examples.",
        ),
    ]

    for heading, bullets, callout in sections:
        story.append(Paragraph(heading, styles["SectionHeading"]))

        if len(bullets) == 1 and len(bullets[0]) > 200:
            story.append(Paragraph(bullets[0], styles["BodySoft"]))
        else:
            items = [
                ListItem(Paragraph(bullet, styles["BodySoft"]), leftIndent=4)
                for bullet in bullets
            ]
            story.append(ListFlowable(items, bulletType="bullet", start="circle", leftIndent=14))
            story.append(Spacer(1, 4))

        if callout:
            story.append(Spacer(1, 2))
            story.append(
                Table(
                    [[Paragraph(f"<b>{callout.split(':', 1)[0]}:</b>{callout.split(':', 1)[1]}", styles["BodySoft"]) ]],
                    colWidths=[175 * mm],
                    style=TableStyle(
                        [
                            ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#eef7f6")),
                            ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#0e7c7b")),
                            ("LEFTPADDING", (0, 0), (-1, -1), 10),
                            ("RIGHTPADDING", (0, 0), (-1, -1), 10),
                            ("TOPPADDING", (0, 0), (-1, -1), 8),
                            ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
                        ]
                    ),
                )
            )

        story.append(Spacer(1, 8))

    return story


def main() -> None:
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    doc = SimpleDocTemplate(
        str(OUTPUT_PATH),
        pagesize=A4,
        rightMargin=16 * mm,
        leftMargin=16 * mm,
        topMargin=16 * mm,
        bottomMargin=16 * mm,
        title="SafeRoute Project Documentation",
        author="GitHub Copilot",
    )
    doc.build(build_document())
    print(f"Wrote {OUTPUT_PATH}")


if __name__ == "__main__":
    main()