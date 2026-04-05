# -------------------------------
# CONFIG: Commit behavior
# -------------------------------
# In the original repository, we only print results instead of committing.
# This prevents unnecessary commits that could complicate forks and upstream merges.
commit=true

# Detect repository origin
origin=$(git remote get-url origin)

# Disable commits if running in the original upstream repo
if [[ $origin == *statsig-io/statuspage* ]]
then
  commit=false
fi


# -------------------------------
# LOAD URL CONFIGURATION
# -------------------------------
# Arrays to store keys and URLs
KEYSARRAY=()
URLSARRAY=()

# Config file format: key=url
urlsConfig="./urls.cfg"
echo "Reading $urlsConfig"

# Read each line and split into key + URL
while read -r line
do
  echo "  $line"
  IFS='=' read -ra TOKENS <<< "$line"
  KEYSARRAY+=(${TOKENS[0]})
  URLSARRAY+=(${TOKENS[1]})
done < "$urlsConfig"


# -------------------------------
# START HEALTH CHECKS
# -------------------------------
echo "***********************"
echo "Starting health checks with ${#KEYSARRAY[@]} configs:"

# Ensure logs directory exists
mkdir -p logs


# -------------------------------
# CHECK EACH URL
# -------------------------------
for (( index=0; index < ${#KEYSARRAY[@]}; index++))
do
  key="${KEYSARRAY[index]}"
  url="${URLSARRAY[index]}"
  echo "  $key=$url"

  # Retry up to 4 times before marking as failed
  for i in 1 2 3 4; 
  do
    response=$(curl --write-out '%{http_code}' --silent --output /dev/null $url)

    # Treat common success and redirect codes as "success"
    if [ "$response" -eq 200 ] || [ "$response" -eq 202 ] || [ "$response" -eq 301 ] || [ "$response" -eq 302 ] || [ "$response" -eq 307 ]; then
      result="success"
    else
      result="failed"
    fi

    # Exit retry loop if successful
    if [ "$result" = "success" ]; then
      break
    fi

    # Wait before retrying
    sleep 5
  done

  # Timestamp for logs
  dateTime=$(date +'%Y-%m-%d %H:%M')

  if [[ $commit == true ]]
  then
    # Append result to log file
    echo $dateTime, $result >> "logs/${key}_report.log"

    # Keep only last 2000 entries to avoid large files
    echo "$(tail -2000 logs/${key}_report.log)" > "logs/${key}_report.log"
  else
    # Print result instead of committing
    echo "    $dateTime, $result"
  fi
done


# -------------------------------
# COMMIT & PUSH LOGS
# -------------------------------
if [[ $commit == true ]]
then
  # Configure Git identity
  git config --global user.name 'Shinei'
  git config --global user.email 'ikx7a@hotmail.com'

  # Stage log files
  git add -A --force logs/

  # Commit changes
  git commit -am '[Automated] Update Health Check Logs'

  # Push to repository
  git push
fi
