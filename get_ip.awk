/Private IP Address:/ { 
    arr[pvt_ip] = $2 
} 
END { 
    print arr[pvt_ip] 
}
