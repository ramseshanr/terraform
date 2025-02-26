provider "aws" {
  region = "us-east-2"
  profile = "default"
}


resource "aws_instance" "mgr" {
    
    count = 1
    key_name= "17-key"
    tags = {
        Name = "TF-17-k8s-Master"
        owner =  "Ramaseshan Rangarajan"
    }
    launch_template {
        id ="lt-05c810971e0111ae7"
        version= "1"
    }


}

resource "aws_instance" "wrk" {
    
    count = 2
    key_name= "17-key"
    tags = {
        Name = "TF-17-k8s-worker-${count.index + 1}"
        owner =  "Ramaseshan Rangarajan"
    }
    launch_template {
        id ="lt-05c810971e0111ae7"
        version= "1"
    }


}

output mgr_private_ips{
  value = aws_instance.mgr[*].private_ip
}


output wrk_private_ips{
  value = aws_instance.wrk[*].private_ip
}

resource "null_resource" "sleep" {
  provisioner "local-exec" {
    command = "sleep 50"  
  }
}

resource "null_resource" "update_inventory" {
  depends_on = [null_resource.sleep]

    provisioner "local-exec" {
    command = <<EOT
      echo "[mgr]" > ~/terraaformbuild/Ansible/k8sinstall/inventory.ini
      echo "mgr ansible_host=${aws_instance.mgr[0].private_ip}" >> ~/terraaformbuild/Ansible/k8sinstall/inventory.ini
      echo "[wrk]" >> ~/terraaformbuild/Ansible/k8sinstall/inventory.ini
      echo "wrk1 ansible_host=${aws_instance.wrk[0].private_ip}" >> ~/terraaformbuild/Ansible/k8sinstall/inventory.ini
      echo "wrk2 ansible_host=${aws_instance.wrk[1].private_ip}" >> ~/terraaformbuild/Ansible/k8sinstall/inventory.ini
    EOT
  }
}
resource "null_resource" "k8s" {
    depends_on = [ null_resource.update_inventory ]
    provisioner "local-exec" {
        command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ~/terraaformbuild/Ansible/k8sinstall/inventory.ini  ~/terraaformbuild/Ansible/k8sinstall/ansiblek8.yaml > k8install.log"
      
    }
  
}

resource "null_resource" "configcopy" {
  depends_on = [ null_resource.k8s ]
  provisioner "local-exec" {
    command =  "ansible-playbook -i ~/terraaformbuild/Ansible/k8sinstall/inventory.ini ~/terraaformbuild/Ansible/k8sinstall/configcopy.yaml > copy.log"
  }
  
}

resource "null_resource" "helm" {
    depends_on = [ null_resource.configcopy ]
    provisioner "local-exec" {
      command = "ansible-playbook ~/terraaformbuild/Ansible/helm/helminstall.yaml > helmappinst.log"
    }
  
}

resource "null_resource" "scale" {
    depends_on = [ null_resource.helm ]
   provisioner "local-exec" {
    command = "ansible-playbook ~/terraaformbuild/Ansible/scale/scale-application.yaml -e Deployment_Name='python' -e Replica_count='5' >scaled.log"
     
   }
}