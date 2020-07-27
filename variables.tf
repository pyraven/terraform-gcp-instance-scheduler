variable "project" {
  default = "<insert projectid here>"
}

# set to every day, at 18:00 hourds (6pm)
# https://crontab.guru/
variable "cron_pattern" {
  default = "0 18 * * *"
}

variable "label_key" {
  default = "instance-scheduler"
}

variable "label_value" {
  default = "enabled"
}

variable "scheduler_function_bucket" {
  default = "<insert bucket name here>"
}