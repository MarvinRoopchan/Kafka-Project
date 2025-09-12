# Roman Numerals Kafka + RDS Postgres App

This project demonstrates a simple **producer-consumer pipeline** using **Apache Kafka** with a **Postgres RDS backend**.  
It converts numbers into **Roman numerals**, publishes them to a Kafka topic, and persists the results in Postgres.

---

## 🚀 Architecture
1. **Producer**  
   - Takes an integer as input.  
   - Converts it into **Roman numerals**.  
   - Publishes the result to a Kafka topic (`roman-topic`).  

2. **Kafka**  
   - Acts as the message broker.  
   - Decouples producer and consumer.  

3. **Consumer**  
   - Subscribes to the Kafka topic.  
   - Reads incoming messages (number → roman numeral).  
   - Inserts results into **Postgres RDS**.  

4. **Postgres (AWS RDS)**  
   - Stores messages in a `roman_numerals` table.  
   - Schema:  
     ```sql
     CREATE TABLE roman_numerals (
         id SERIAL PRIMARY KEY,
         number INT NOT NULL,
         roman TEXT NOT NULL,
         created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
     );
     ```

---

## 🛠️ Prerequisites
- **Docker** + **Docker Compose**  
- **Kafka** & **Zookeeper** (can be local via Docker or managed service)  
- **AWS RDS Postgres** instance  
- Python 3.9+  

---

## ⚙️ Setup

### 1. Clone the repo
```bash
git clone https://github.com/your-username/roman-numerals-kafka-rds.git
cd roman-numerals-kafka-rds
