from django.urls import path

from api import dashboard_views
from api import views


urlpatterns = [
    path("dashboard/login", dashboard_views.dashboard_login, name="dashboard_login"),
    path("dashboard/logout", dashboard_views.dashboard_logout, name="dashboard_logout"),
    path("", dashboard_views.dashboard_home, name="dashboard_home"),
    path("dashboard", dashboard_views.dashboard_home, name="dashboard_home"),
    path("dashboard/users", dashboard_views.users_list, name="users_list"),
    path("dashboard/users/new", dashboard_views.user_create, name="user_create"),
    path("dashboard/users/<int:user_id>/edit", dashboard_views.user_edit, name="user_edit"),
    path("dashboard/users/<int:user_id>/delete", dashboard_views.user_delete, name="user_delete"),
    path("dashboard/admins", dashboard_views.admins_list, name="admins_list"),
    path("dashboard/admins/new", dashboard_views.admin_create, name="admin_create"),
    path("dashboard/admins/<int:admin_id>/update", dashboard_views.admin_update, name="admin_update"),
    path("dashboard/routes", dashboard_views.routes_list, name="routes_list"),
    path("dashboard/routes/<uuid:route_id>", dashboard_views.route_detail, name="route_detail"),
    path("dashboard/analytics", dashboard_views.analytics, name="analytics"),
    path("health", views.health),
    path("auth/register", views.register),
    path("auth/login", views.login),
    path("auth/google", views.google_login),
    path("routes/record", views.record_route),
    path("routes/user/<int:user_id>", views.get_user_routes),
    path("transport-modes", views.create_transport_mode),
    path("locations", views.create_location),
    path("routes", views.create_route_meta),
    path("travel_logs", views.create_travel_log),
    path("safety_reports", views.create_safety_report),
    path("incidents", views.create_incident),
]
