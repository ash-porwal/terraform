variable "ashish_first_var" {
  
}

// we will be printing the variable name which we took in interactive session
output "printvarname" {
    value = "This is you said - ${var.ashish_first_var}"
  
}

// so we can keep all the variables in a separate file and can be used in other .tf files
