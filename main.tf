provider "google" {
  project = var.project
  region  = "us-central1"
  zone    = "us-central1-c"
}

resource "google_pubsub_topic" "topic" {
  name = "instance-scheduler-topic"
}

resource "google_cloud_scheduler_job" "job" {
  name        = "instance-scheduler"
  description = "Cloud Scheduler to turn off labeled VMs to save on cost and reduce risk."
  schedule    = var.cron_pattern

  pubsub_target {
    topic_name = google_pubsub_topic.topic.id
    data       = base64encode("i am a robot...beep boop beep boop")
  }
}

resource "google_storage_bucket" "bucket" {
  name = var.scheduler_function_bucket
}

resource "google_storage_bucket_object" "archive" {
  name   = "function.zip"
  bucket = google_storage_bucket.bucket.name
  source = "gcp/function.zip"
}

resource "google_service_account" "sa" {
  account_id   = "instance-scheduler-srv-accnt"
  display_name = "instance-scheduler-srv-accnt"
}

resource "google_project_iam_custom_role" "sa_custom_role" {
  role_id     = "instance.scheduler"
  title       = "Instance Scheduler Role"
  description = "Ability to turn off instances with a specific label at a specific time."
  permissions = [
    "compute.instances.list",
    "compute.instances.stop",
    "compute.zones.list",
  ]
}

resource "google_project_iam_member" "sa-iam-member" {
  project = var.project
  role    = "projects/${var.project}/roles/${google_project_iam_custom_role.sa_custom_role.role_id}"
  member  = "serviceAccount:${google_service_account.sa.email}"

  depends_on = [
    google_service_account.sa
  ]
}

resource "google_cloudfunctions_function" "function" {
  name                  = "instance-scheduler-function"
  description           = "Cloud function to do the heavy lifting"
  available_memory_mb   = 128
  source_archive_bucket = "${google_storage_bucket.bucket.name}"
  source_archive_object = "${google_storage_bucket_object.archive.name}"
  runtime               = "python37"

  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = google_pubsub_topic.topic.name
    failure_policy {
      retry = false
    }
  }

  timeout               = 120
  entry_point           = "instance_scheduler_start"
  service_account_email = google_service_account.sa.email

  environment_variables = {
    PROJECT     = var.project
    LABEL_KEY   = var.label_key
    LABEL_VALUE = var.label_value
  }
  depends_on = [
    google_service_account.sa
  ]
}