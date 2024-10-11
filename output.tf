output "aws_db_instance_affine_username" {
  value = aws_db_instance.affine.username
}

output "aws_db_instance_affine_dbname" {
  value = aws_db_instance.affine.db_name
}
output "url_db" {
  #sensitive = true
  value = "postgres://${aws_db_instance.affine.username}@affine-db.c5o8u4w2mp29.eu-west-3.rds.amazonaws.com:5432/${aws_db_instance.affine.db_name}"
}
