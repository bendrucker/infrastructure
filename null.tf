resource "null_resource" "n" { 
  triggers = {
    foober = ""
    bar = ""
  }
}