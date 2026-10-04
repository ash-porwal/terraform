# ways to comment in terraform 
# this is first comment using #
// this is also a comment

# general syntax of terraform
// block "label" "label2" {  # we can have n numbers of label
//      identifier = expression
// }

# lets write basic terraform syntax, where we wont be creating infra
# but we will be just writing random output
output "ashish_output" {
    value = "ashish's first terraform"
}