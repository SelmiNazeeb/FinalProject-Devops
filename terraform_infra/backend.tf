terraform {
  backend "s3" {
    # Leave blank values – they’ll be filled during init
    bucket         = ""  # Provided in buildspec
    key            = ""  # Provided in buildspec
    region         = ""  # Provided in buildspec
    dynamodb_table = ""  # Provided in buildspec
  }
}
