
##################
# Buckets in google
##################
# organization specific artifact repo
resource "google_artifact_registry_repository" "orgrepo" {
  provider      = google-beta
  project       = var.project
  location      = "us-central1"
  repository_id = var.organization
  description   = "organization specific docker repo"
  format        = "DOCKER"
}
# organization specific data bucket
resource "google_storage_bucket" "sparkstorage" {
  project                     = var.project
  name                        = "streamstate-sparkstorage-${var.organization}"
  location                    = "US"
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "sparkhistory" {
  name    = "spark-history-server/empty"
  content = "helloworld"
  bucket  = google_storage_bucket.sparkstorage.name
}

# this probably isnt needed, since there aren't "folders" on gcs
# it IS needed for spark history because the spark history
# application needs to "see" the folder to scan it, even if its
# a fake folder
resource "google_storage_bucket_object" "checkpoint" {
  name    = "checkpoint/empty"
  content = "helloworld"
  bucket  = google_storage_bucket.sparkstorage.name
}

# organization specific history server
#resource "google_storage_bucket" "sparkhistory" {
#  project                     = var.project
#  name                        = "streamstate-historyserver-${var.organization}"
##  location                    = "US"
#  force_destroy               = true
#  uniform_bucket_level_access = true
#}

# organization specific argo logs
resource "google_storage_bucket" "argologs" {
  project                     = var.project
  name                        = "streamstate-argologs-${var.organization}"
  location                    = "US"
  force_destroy               = true
  uniform_bucket_level_access = true
}

##################
# Service accounts in google, to be mapped to kuberenetes secrets
##################


# it would be nice for this to be per app, but may not be feasible 
# since may not be able to create service accounts per job.
# Remember...I want all gcp resources defined through TF
# this is the service acccount for spark jobs and 
# can write to spark storage

resource "google_service_account" "docker-write" {
  project      = var.project
  account_id   = "docker-write-${var.organization}"
  display_name = "docker-write-${var.organization}"
}
resource "google_service_account" "spark-gcs" {
  project      = var.project
  account_id   = "spark-gcs-${var.organization}"
  display_name = "Spark Service account ${var.organization}"
}

resource "google_service_account" "argo" {
  project      = var.project
  account_id   = "argo-${var.organization}"
  display_name = "Argo service account for ${var.organization}"
}

## needed for the initial write to firestore from argo events
## run in argo-events namespace instead of sparkmain
resource "google_service_account" "firestore" {
  project      = var.project
  account_id   = "firestore-${var.organization}"
  display_name = "Firestore service account ${var.organization}"
}

## needed for the initial write to firestore from argo events
## run in argo-events namespace instead of sparkmain
resource "google_service_account" "firestore-viewer" {
  project      = var.project
  account_id   = "firestore-viewer-${var.organization}"
  display_name = "Firestore service account read only ${var.organization}"
}

resource "google_service_account" "spark-history" {
  project      = var.project
  account_id   = "spark-history-${var.organization}"
  display_name = "Spark history account ${var.organization}"
}

#write access to organization artifactory
resource "google_artifact_registry_repository_iam_member" "providereadwrite" {
  provider   = google-beta
  project    = var.project
  location   = google_artifact_registry_repository.orgrepo.location
  repository = google_artifact_registry_repository.orgrepo.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.docker-write.email}"
}
# read access to project wide artifactory
resource "google_artifact_registry_repository_iam_member" "read" {
  provider   = google-beta
  project    = var.project
  location   = "us-central1"
  repository = var.project # see ../../global/global.tf#  
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.docker-write.email}"
}

## access to firestore from spark
resource "google_project_iam_member" "firestore_user" {
  role    = "roles/datastore.user"
  project = var.project
  member  = "serviceAccount:${google_service_account.spark-gcs.email}"
}

## access to firestore from argo-events
resource "google_project_iam_member" "firestore_user_argoevents" {
  role    = "roles/datastore.user"
  project = var.project
  member  = "serviceAccount:${google_service_account.firestore.email}"
}

## access to firestore from rest api
resource "google_project_iam_member" "firestore_viewer" {
  role    = "roles/datastore.viewer"
  project = var.project
  member  = "serviceAccount:${google_service_account.firestore-viewer.email}"
}


#write access to gcs
resource "google_storage_bucket_iam_member" "sparkadmin" {
  bucket = google_storage_bucket.sparkstorage.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.spark-gcs.email}"
}

#resource "google_storage_bucket_iam_member" "sparkhistoryadmin" {
#  bucket = google_storage_bucket.sparkhistory.name
#  role   = "roles/storage.admin"
#  member = "serviceAccount:${google_service_account.spark-gcs.email}"
#}

resource "google_storage_bucket_iam_member" "argologadmin" {
  bucket = google_storage_bucket.argologs.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.argo.email}"
}

resource "google_storage_bucket_iam_member" "argologfirestore" {
  bucket = google_storage_bucket.argologs.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.firestore.email}"
}

resource "google_storage_bucket_iam_member" "argologdockerwrite" {
  bucket = google_storage_bucket.argologs.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.docker-write.email}"
}

# artifact read access to cluster service account to read docker containers
resource "google_artifact_registry_repository_iam_member" "clusterread" {
  provider   = google-beta
  project    = var.project
  location   = google_artifact_registry_repository.orgrepo.location
  repository = google_artifact_registry_repository.orgrepo.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.cluster_email}"
}

# apparently need custom role for minimal permissions... :|
resource "google_project_iam_custom_role" "readbucketrole" {
  role_id     = "readbucket"
  title       = "read from bucket"
  description = "Provides minimal access to read from bucket"
  permissions = [
    "storage.buckets.get", "storage.objects.list", "storage.objects.get"
  ]
  project = var.project
}


resource "google_storage_bucket_iam_member" "sparkhistoryread" {
  bucket = google_storage_bucket.sparkstorage.name
  role   = "projects/${var.project}/roles/${google_project_iam_custom_role.readbucketrole.role_id}"
  member = "serviceAccount:${google_service_account.spark-history.email}"
}


//TODO should this be once per cluster?? (yes)
//need to create "random" id on each service account creation
// see https://github.com/jetstack/cert-manager/issues/2069#issuecomment-531428320
resource "google_service_account" "dns" {
  project      = var.project
  account_id   = "dns-${var.organization}" # ${random_string.sa.id}"
  display_name = "DNS solver for ${var.organization}"
}

## TODO, just a test to see if minimal access is incorrect
## ugh, it is...I needed admin role for it to work...
resource "google_project_iam_member" "minimaldnsrole" {
  project = var.project
  role    = "roles/dns.admin" # "projects/${var.project}/roles/${google_project_iam_custom_role.minimaldnsrole.role_id}"
  member  = "serviceAccount:${google_service_account.dns.email}"
}
