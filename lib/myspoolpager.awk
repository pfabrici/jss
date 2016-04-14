/^\|/ { printf("%s\n",substr($0,3,length($0)-4)); }
