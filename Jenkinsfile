pipeline {
    agent {
        node {
            label 'master'
        }
    }

    stages {

        stage('terraform started') {
            steps {
                sh 'echo "Started...!" '
            }
        }
        stage('git clone') {
            steps {
                sh  'rm -r *;git clone https://github.com/shyamkumarchauhan/terraform-web.git'
            }
        }
        stage('tfsvars create'){
            steps {
                sh 'cp /home/ubuntu/variables.tf ./terraform-web/; cp /home/ubuntu/provider.tf ./terraform-web/'
            }
        }
        stage('terraform init') {
            steps {
                sh 'terraform init ./terraform-web'
            }
        }
        stage('terraform apply') {
            steps {
                sh 'ls ./terraform-web;export AWS_DEFAULT_REGION=us-east-2;terraform apply -input=false -auto-approve ./terraform-web;cp -rp ./terraform-web /var/tmp/terraform-poc-asg-delete'
            }
        }
        stage('terraform ended') {
            steps {
                sh 'echo "Ended....!!"'
            }
        }

        
    }
}
