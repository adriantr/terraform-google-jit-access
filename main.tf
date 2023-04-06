locals {
  jit_name = "jit"
}

resource "google_compute_global_address" "jit" {
  project = var.project_id
  name    = local.jit_name
}

resource "google_project_service_identity" "iap" {
  project  = var.project_id
  provider = google-beta
  service  = "iap.googleapis.com"
}

resource "google_iap_brand" "main" {
  project           = var.project_id
  support_email     = var.support_email
  application_title = var.application_title
}

resource "google_iap_client" "jit" {
  display_name = "JIT Client"
  brand        = google_iap_brand.main.name
}

resource "google_service_account" "jit" {
  project    = var.project_id
  account_id = "${local.jit_name}-sa"
}

resource "google_project_iam_member" "jit" {
  for_each = toset(["roles/cloudasset.viewer", "roles/iam.securityAdmin"])

  project = var.target_project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.jit.email}"
}

resource "google_project_iam_member" "jit-iap" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_project_service_identity.iap.email}"
}

resource "google_compute_managed_ssl_certificate" "jit" {
  project = var.project_id
  name    = local.jit_name
  managed {
    domains = [var.dns_name]
  }
}

resource "google_compute_region_network_endpoint_group" "jit" {
  project               = var.project_id
  name                  = local.jit_name
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  cloud_run {
    service = local.jit_name
  }
}

resource "google_compute_backend_service" "jit" {
  project = var.project_id
  name    = "${local.jit_name}-backend"

  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30

  iap {
    oauth2_client_id     = google_iap_client.jit.client_id
    oauth2_client_secret = google_iap_client.jit.secret
  }

  backend {
    group = google_compute_region_network_endpoint_group.jit.id
  }
}

resource "google_compute_url_map" "jit" {
  project         = var.project_id
  name            = local.jit_name
  default_service = google_compute_backend_service.jit.id
}

resource "google_compute_target_https_proxy" "jit" {
  project = var.project_id
  name    = local.jit_name
  url_map = google_compute_url_map.jit.id

  ssl_certificates = [
    google_compute_managed_ssl_certificate.jit.id
  ]
}

resource "google_compute_global_forwarding_rule" "jit" {
  project    = var.project_id
  name       = local.jit_name
  target     = google_compute_target_https_proxy.jit.id
  port_range = "443"
  ip_address = google_compute_global_address.jit.address
}

resource "google_cloud_run_service" "jit" {
  project  = var.project_id
  name     = local.jit_name
  location = var.region

  metadata {
    annotations = {
      "run.googleapis.com/ingress" = "internal-and-cloud-load-balancing"
    }
  }
  template {
    spec {
      containers {
        image = var.jit_image
        env {
          name  = "RESOURCE_SCOPE"
          value = "projects/${var.target_project_id}"
        }
        env {
          name  = "ACTIVATION_TIMEOUT"
          value = "60"
        }
        env {
          name  = "JUSTIFICATION_HINT"
          value = "Why do you need the access?"
        }
        env {
          name  = "JUSTIFICATION_PATTERN"
          value = ".*"
        }
        env {
          name  = "IAP_BACKEND_SERVICE_ID"
          value = google_compute_backend_service.jit.generated_id
        }
      }
      service_account_name = google_service_account.jit.email
    }
  }
}

resource "google_cloud_run_service_iam_member" "jit" {
  location = google_cloud_run_service.jit.location
  project  = google_cloud_run_service.jit.project
  service  = google_cloud_run_service.jit.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_iap_web_backend_service_iam_member" "jit" {
  project             = var.project_id
  web_backend_service = google_compute_backend_service.jit.name
  role                = "roles/iap.httpsResourceAccessor"
  member              = "group:${var.access_group}"
}

// Making a role eligible for JIT request

resource "google_project_iam_member" "jit_role" {
  for_each = toset(var.roles)

  role    = each.key
  member  = "group:${var.access_group}"
  project = var.target_project_id
  condition {
    title      = "JIT access activation"
    expression = "has({}.jitAccessConstraint)"
  }
}
