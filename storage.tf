# --- S3 bucket for static assets ---
resource "aws_s3_bucket" "assets" {
  bucket = var.assets_bucket_name

  tags = {
    Name    = "${var.project_name}-assets"
    Project = var.project_name
  }
}

# --- Block ALL public access ---
resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy      = true
  ignore_public_acls       = true
  restrict_public_buckets  = true
}

# --- Versioning ---
resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

# --- Default encryption (not asked for, but you always want it) ---
resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
