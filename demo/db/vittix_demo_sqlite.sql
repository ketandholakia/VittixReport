
PRAGMA foreign_keys = OFF;

DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS suppliers;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS items;
DROP TABLE IF EXISTS sales_invoice;
DROP TABLE IF EXISTS sales_invoice_items;
DROP TABLE IF EXISTS purchase_invoice;
DROP TABLE IF EXISTS purchase_invoice_items;

CREATE TABLE customers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    city TEXT,
    phone TEXT,
    email TEXT
);

CREATE TABLE suppliers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    city TEXT,
    phone TEXT
);

CREATE TABLE categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT
);

CREATE TABLE items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    category_id INTEGER,
    price REAL,
    FOREIGN KEY(category_id) REFERENCES categories(id)
);

CREATE TABLE sales_invoice (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_no TEXT,
    customer_id INTEGER,
    invoice_date TEXT,
    total REAL,
    FOREIGN KEY(customer_id) REFERENCES customers(id)
);

CREATE TABLE sales_invoice_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_id INTEGER,
    item_id INTEGER,
    qty REAL,
    rate REAL,
    amount REAL,
    FOREIGN KEY(invoice_id) REFERENCES sales_invoice(id),
    FOREIGN KEY(item_id) REFERENCES items(id)
);

CREATE TABLE purchase_invoice (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_no TEXT,
    supplier_id INTEGER,
    invoice_date TEXT,
    total REAL,
    FOREIGN KEY(supplier_id) REFERENCES suppliers(id)
);

CREATE TABLE purchase_invoice_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_id INTEGER,
    item_id INTEGER,
    qty REAL,
    rate REAL,
    amount REAL,
    FOREIGN KEY(invoice_id) REFERENCES purchase_invoice(id),
    FOREIGN KEY(item_id) REFERENCES items(id)
);

INSERT INTO categories(name) VALUES('Electronics');
INSERT INTO categories(name) VALUES('Stationery');
INSERT INTO categories(name) VALUES('Hardware');
INSERT INTO categories(name) VALUES('Office Supplies');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 1','Rajkot','9000000001','cust1@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 2','Delhi','9000000002','cust2@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 3','Delhi','9000000003','cust3@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 4','Surat','9000000004','cust4@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 5','Delhi','9000000005','cust5@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 6','Rajkot','9000000006','cust6@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 7','Surat','9000000007','cust7@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 8','Pune','9000000008','cust8@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 9','Delhi','9000000009','cust9@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 10','Surat','9000000010','cust10@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 11','Rajkot','9000000011','cust11@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 12','Ahmedabad','9000000012','cust12@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 13','Pune','9000000013','cust13@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 14','Pune','9000000014','cust14@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 15','Surat','9000000015','cust15@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 16','Delhi','9000000016','cust16@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 17','Delhi','9000000017','cust17@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 18','Delhi','9000000018','cust18@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 19','Ahmedabad','9000000019','cust19@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 20','Delhi','9000000020','cust20@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 21','Ahmedabad','9000000021','cust21@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 22','Delhi','9000000022','cust22@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 23','Rajkot','9000000023','cust23@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 24','Mumbai','9000000024','cust24@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 25','Ahmedabad','9000000025','cust25@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 26','Pune','9000000026','cust26@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 27','Pune','9000000027','cust27@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 28','Rajkot','9000000028','cust28@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 29','Pune','9000000029','cust29@demo.com');
INSERT INTO customers(name,city,phone,email) VALUES('Customer 30','Delhi','9000000030','cust30@demo.com');
INSERT INTO suppliers(name,city,phone) VALUES('Supplier 1','Ahmedabad','8000000001');
INSERT INTO suppliers(name,city,phone) VALUES('Supplier 2','Rajkot','8000000002');
INSERT INTO suppliers(name,city,phone) VALUES('Supplier 3','Mumbai','8000000003');
INSERT INTO suppliers(name,city,phone) VALUES('Supplier 4','Pune','8000000004');
INSERT INTO suppliers(name,city,phone) VALUES('Supplier 5','Ahmedabad','8000000005');
INSERT INTO suppliers(name,city,phone) VALUES('Supplier 6','Rajkot','8000000006');
INSERT INTO suppliers(name,city,phone) VALUES('Supplier 7','Ahmedabad','8000000007');
INSERT INTO suppliers(name,city,phone) VALUES('Supplier 8','Ahmedabad','8000000008');
INSERT INTO suppliers(name,city,phone) VALUES('Supplier 9','Surat','8000000009');
INSERT INTO suppliers(name,city,phone) VALUES('Supplier 10','Surat','8000000010');
INSERT INTO items(name,category_id,price) VALUES('Laptop',4,3568);
INSERT INTO items(name,category_id,price) VALUES('Mouse',4,278);
INSERT INTO items(name,category_id,price) VALUES('Keyboard',1,2454);
INSERT INTO items(name,category_id,price) VALUES('Monitor',3,4350);
INSERT INTO items(name,category_id,price) VALUES('Pen',4,3337);
INSERT INTO items(name,category_id,price) VALUES('Notebook',1,1494);
INSERT INTO items(name,category_id,price) VALUES('Printer',1,2967);
INSERT INTO items(name,category_id,price) VALUES('Router',3,445);
INSERT INTO items(name,category_id,price) VALUES('Cable',2,1059);
INSERT INTO items(name,category_id,price) VALUES('Chair',2,1937);
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0001',17,'2025-04-12',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(1,6,5,1294,6470);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(1,3,3,431,1293);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(1,2,4,659,2636);
UPDATE sales_invoice SET total=10399 WHERE id=1;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0002',27,'2025-05-29',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(2,5,3,633,1899);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(2,6,3,825,2475);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(2,2,3,1092,3276);
UPDATE sales_invoice SET total=7650 WHERE id=2;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0003',22,'2025-03-27',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(3,2,2,1918,3836);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(3,10,4,738,2952);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(3,2,2,994,1988);
UPDATE sales_invoice SET total=8776 WHERE id=3;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0004',10,'2025-02-18',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(4,6,5,508,2540);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(4,1,3,1665,4995);
UPDATE sales_invoice SET total=7535 WHERE id=4;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0005',14,'2025-05-05',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(5,1,1,1869,1869);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(5,1,3,583,1749);
UPDATE sales_invoice SET total=3618 WHERE id=5;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0006',19,'2025-04-13',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(6,8,3,1066,3198);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(6,2,2,1732,3464);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(6,8,5,657,3285);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(6,9,1,851,851);
UPDATE sales_invoice SET total=10798 WHERE id=6;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0007',25,'2025-04-01',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(7,6,1,663,663);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(7,9,2,1843,3686);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(7,5,3,636,1908);
UPDATE sales_invoice SET total=6257 WHERE id=7;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0008',10,'2025-02-02',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(8,5,3,264,792);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(8,5,5,493,2465);
UPDATE sales_invoice SET total=3257 WHERE id=8;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0009',29,'2025-06-18',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(9,7,2,946,1892);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(9,3,2,1818,3636);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(9,9,2,181,362);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(9,1,5,1954,9770);
UPDATE sales_invoice SET total=15660 WHERE id=9;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0010',20,'2025-06-08',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(10,10,5,491,2455);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(10,10,1,1652,1652);
UPDATE sales_invoice SET total=4107 WHERE id=10;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0011',24,'2025-04-04',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(11,9,1,759,759);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(11,8,4,833,3332);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(11,3,5,432,2160);
UPDATE sales_invoice SET total=6251 WHERE id=11;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0012',19,'2025-03-08',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(12,5,3,452,1356);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(12,4,4,748,2992);
UPDATE sales_invoice SET total=4348 WHERE id=12;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0013',18,'2025-01-25',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(13,1,4,678,2712);
UPDATE sales_invoice SET total=2712 WHERE id=13;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0014',15,'2025-01-20',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(14,5,1,1614,1614);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(14,6,2,344,688);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(14,8,5,1503,7515);
UPDATE sales_invoice SET total=9817 WHERE id=14;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0015',8,'2025-03-24',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(15,7,2,1066,2132);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(15,6,3,405,1215);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(15,10,4,365,1460);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(15,6,2,172,344);
UPDATE sales_invoice SET total=5151 WHERE id=15;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0016',29,'2025-01-15',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(16,8,1,746,746);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(16,9,4,571,2284);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(16,2,4,1235,4940);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(16,7,1,857,857);
UPDATE sales_invoice SET total=8827 WHERE id=16;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0017',7,'2025-02-21',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(17,1,5,138,690);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(17,3,3,1156,3468);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(17,8,3,1648,4944);
UPDATE sales_invoice SET total=9102 WHERE id=17;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0018',5,'2025-03-06',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(18,7,2,457,914);
UPDATE sales_invoice SET total=914 WHERE id=18;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0019',8,'2025-01-18',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(19,10,1,1323,1323);
UPDATE sales_invoice SET total=1323 WHERE id=19;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0020',19,'2025-04-09',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(20,7,3,1544,4632);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(20,4,5,894,4470);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(20,6,5,520,2600);
UPDATE sales_invoice SET total=11702 WHERE id=20;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0021',12,'2025-03-11',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(21,5,1,1353,1353);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(21,2,4,308,1232);
UPDATE sales_invoice SET total=2585 WHERE id=21;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0022',12,'2025-01-05',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(22,4,5,358,1790);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(22,6,2,1528,3056);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(22,2,4,1782,7128);
UPDATE sales_invoice SET total=11974 WHERE id=22;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0023',3,'2025-02-03',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(23,3,5,1451,7255);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(23,4,5,165,825);
UPDATE sales_invoice SET total=8080 WHERE id=23;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0024',10,'2025-06-05',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(24,3,2,674,1348);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(24,5,4,1861,7444);
UPDATE sales_invoice SET total=8792 WHERE id=24;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0025',8,'2025-01-11',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(25,2,2,1980,3960);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(25,8,5,442,2210);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(25,2,4,1376,5504);
UPDATE sales_invoice SET total=11674 WHERE id=25;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0026',26,'2025-02-23',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(26,4,4,1161,4644);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(26,10,5,116,580);
UPDATE sales_invoice SET total=5224 WHERE id=26;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0027',13,'2025-06-07',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(27,9,4,1932,7728);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(27,9,4,1034,4136);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(27,4,2,1820,3640);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(27,4,3,1037,3111);
UPDATE sales_invoice SET total=18615 WHERE id=27;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0028',29,'2025-04-24',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(28,10,3,983,2949);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(28,4,2,1713,3426);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(28,9,4,288,1152);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(28,10,2,421,842);
UPDATE sales_invoice SET total=8369 WHERE id=28;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0029',5,'2025-01-19',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(29,6,5,293,1465);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(29,2,4,621,2484);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(29,2,3,555,1665);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(29,8,5,166,830);
UPDATE sales_invoice SET total=6444 WHERE id=29;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0030',1,'2025-05-06',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(30,2,2,641,1282);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(30,9,4,1668,6672);
UPDATE sales_invoice SET total=7954 WHERE id=30;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0031',24,'2025-07-06',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(31,5,2,1910,3820);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(31,4,1,1754,1754);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(31,8,5,123,615);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(31,3,1,1437,1437);
UPDATE sales_invoice SET total=7626 WHERE id=31;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0032',12,'2025-01-26',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(32,4,3,1793,5379);
UPDATE sales_invoice SET total=5379 WHERE id=32;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0033',12,'2025-02-17',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(33,6,5,537,2685);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(33,6,2,408,816);
UPDATE sales_invoice SET total=3501 WHERE id=33;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0034',11,'2025-04-15',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(34,10,2,1920,3840);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(34,4,3,1983,5949);
UPDATE sales_invoice SET total=9789 WHERE id=34;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0035',23,'2025-05-19',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(35,1,4,927,3708);
UPDATE sales_invoice SET total=3708 WHERE id=35;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0036',19,'2025-07-02',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(36,6,2,1996,3992);
UPDATE sales_invoice SET total=3992 WHERE id=36;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0037',29,'2025-05-29',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(37,10,4,1187,4748);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(37,9,3,547,1641);
UPDATE sales_invoice SET total=6389 WHERE id=37;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0038',15,'2025-04-21',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(38,7,2,703,1406);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(38,9,1,545,545);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(38,3,5,720,3600);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(38,6,1,429,429);
UPDATE sales_invoice SET total=5980 WHERE id=38;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0039',25,'2025-01-14',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(39,4,2,601,1202);
UPDATE sales_invoice SET total=1202 WHERE id=39;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0040',7,'2025-01-18',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(40,7,3,1162,3486);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(40,3,3,1053,3159);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(40,2,2,667,1334);
UPDATE sales_invoice SET total=7979 WHERE id=40;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0041',3,'2025-05-19',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(41,8,2,1260,2520);
UPDATE sales_invoice SET total=2520 WHERE id=41;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0042',1,'2025-04-16',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(42,5,4,177,708);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(42,1,1,1429,1429);
UPDATE sales_invoice SET total=2137 WHERE id=42;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0043',7,'2025-03-04',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(43,6,2,1115,2230);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(43,7,4,1919,7676);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(43,7,1,1155,1155);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(43,9,1,303,303);
UPDATE sales_invoice SET total=11364 WHERE id=43;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0044',10,'2025-06-24',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(44,2,1,1170,1170);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(44,1,2,564,1128);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(44,3,2,1597,3194);
UPDATE sales_invoice SET total=5492 WHERE id=44;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0045',5,'2025-03-01',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(45,4,1,550,550);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(45,4,1,817,817);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(45,6,5,1310,6550);
UPDATE sales_invoice SET total=7917 WHERE id=45;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0046',8,'2025-03-24',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(46,2,4,604,2416);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(46,4,4,861,3444);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(46,7,1,1194,1194);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(46,7,5,1872,9360);
UPDATE sales_invoice SET total=16414 WHERE id=46;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0047',24,'2025-05-25',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(47,1,2,1871,3742);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(47,5,4,689,2756);
UPDATE sales_invoice SET total=6498 WHERE id=47;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0048',21,'2025-01-13',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(48,6,1,1966,1966);
UPDATE sales_invoice SET total=1966 WHERE id=48;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0049',24,'2025-03-05',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(49,4,3,1510,4530);
UPDATE sales_invoice SET total=4530 WHERE id=49;
INSERT INTO sales_invoice(invoice_no,customer_id,invoice_date,total) VALUES('SI-0050',2,'2025-05-01',0);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(50,1,1,1775,1775);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(50,3,5,1303,6515);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(50,6,5,600,3000);
INSERT INTO sales_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(50,1,4,1726,6904);
UPDATE sales_invoice SET total=18194 WHERE id=50;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0001',6,'2025-07-02',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(1,9,15,751,11265);
UPDATE purchase_invoice SET total=11265 WHERE id=1;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0002',1,'2025-05-05',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(2,2,17,121,2057);
UPDATE purchase_invoice SET total=2057 WHERE id=2;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0003',2,'2025-06-22',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(3,4,8,1171,9368);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(3,2,8,507,4056);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(3,8,18,1146,20628);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(3,8,14,555,7770);
UPDATE purchase_invoice SET total=41822 WHERE id=3;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0004',6,'2025-02-02',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(4,5,12,144,1728);
UPDATE purchase_invoice SET total=1728 WHERE id=4;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0005',4,'2025-01-01',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(5,1,8,1153,9224);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(5,4,17,1454,24718);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(5,6,18,333,5994);
UPDATE purchase_invoice SET total=39936 WHERE id=5;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0006',9,'2025-01-19',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(6,10,14,448,6272);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(6,5,8,1149,9192);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(6,8,19,446,8474);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(6,7,20,88,1760);
UPDATE purchase_invoice SET total=25698 WHERE id=6;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0007',8,'2025-02-15',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(7,8,10,1339,13390);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(7,3,20,1470,29400);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(7,1,20,1467,29340);
UPDATE purchase_invoice SET total=72130 WHERE id=7;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0008',4,'2025-05-20',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(8,1,9,157,1413);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(8,7,10,869,8690);
UPDATE purchase_invoice SET total=10103 WHERE id=8;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0009',1,'2025-01-06',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(9,3,5,998,4990);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(9,7,10,1301,13010);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(9,3,5,224,1120);
UPDATE purchase_invoice SET total=19120 WHERE id=9;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0010',3,'2025-05-26',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(10,5,15,447,6705);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(10,5,12,963,11556);
UPDATE purchase_invoice SET total=18261 WHERE id=10;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0011',2,'2025-03-03',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(11,7,18,688,12384);
UPDATE purchase_invoice SET total=12384 WHERE id=11;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0012',7,'2025-01-30',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(12,7,5,1066,5330);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(12,1,18,111,1998);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(12,1,17,301,5117);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(12,9,7,88,616);
UPDATE purchase_invoice SET total=13061 WHERE id=12;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0013',3,'2025-03-19',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(13,3,12,612,7344);
UPDATE purchase_invoice SET total=7344 WHERE id=13;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0014',9,'2025-03-17',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(14,5,11,148,1628);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(14,9,5,234,1170);
UPDATE purchase_invoice SET total=2798 WHERE id=14;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0015',7,'2025-06-12',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(15,3,15,481,7215);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(15,6,7,900,6300);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(15,2,5,1442,7210);
UPDATE purchase_invoice SET total=20725 WHERE id=15;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0016',3,'2025-04-22',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(16,6,15,995,14925);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(16,10,18,142,2556);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(16,1,9,1080,9720);
UPDATE purchase_invoice SET total=27201 WHERE id=16;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0017',2,'2025-05-08',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(17,10,19,1179,22401);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(17,2,18,318,5724);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(17,10,12,404,4848);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(17,3,19,811,15409);
UPDATE purchase_invoice SET total=48382 WHERE id=17;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0018',7,'2025-04-10',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(18,8,10,1033,10330);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(18,10,9,1017,9153);
UPDATE purchase_invoice SET total=19483 WHERE id=18;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0019',3,'2025-03-09',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(19,1,9,364,3276);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(19,10,13,607,7891);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(19,2,6,993,5958);
UPDATE purchase_invoice SET total=17125 WHERE id=19;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0020',10,'2025-07-02',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(20,1,15,1213,18195);
UPDATE purchase_invoice SET total=18195 WHERE id=20;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0021',10,'2025-03-25',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(21,1,18,395,7110);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(21,9,18,1236,22248);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(21,5,19,1372,26068);
UPDATE purchase_invoice SET total=55426 WHERE id=21;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0022',5,'2025-06-30',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(22,4,5,239,1195);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(22,9,8,165,1320);
UPDATE purchase_invoice SET total=2515 WHERE id=22;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0023',7,'2025-02-27',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(23,8,19,521,9899);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(23,2,11,1458,16038);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(23,10,12,737,8844);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(23,4,15,1215,18225);
UPDATE purchase_invoice SET total=53006 WHERE id=23;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0024',9,'2025-07-05',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(24,5,14,115,1610);
UPDATE purchase_invoice SET total=1610 WHERE id=24;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0025',1,'2025-05-18',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(25,2,17,598,10166);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(25,4,11,1449,15939);
UPDATE purchase_invoice SET total=26105 WHERE id=25;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0026',3,'2025-07-08',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(26,5,6,549,3294);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(26,4,18,1232,22176);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(26,9,9,1227,11043);
UPDATE purchase_invoice SET total=36513 WHERE id=26;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0027',2,'2025-01-28',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(27,7,15,1136,17040);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(27,10,5,157,785);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(27,7,9,1438,12942);
UPDATE purchase_invoice SET total=30767 WHERE id=27;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0028',6,'2025-04-22',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(28,3,7,219,1533);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(28,4,20,517,10340);
UPDATE purchase_invoice SET total=11873 WHERE id=28;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0029',8,'2025-02-04',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(29,2,6,231,1386);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(29,8,12,73,876);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(29,9,10,941,9410);
UPDATE purchase_invoice SET total=11672 WHERE id=29;
INSERT INTO purchase_invoice(invoice_no,supplier_id,invoice_date,total) VALUES('PI-0030',8,'2025-06-30',0);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(30,5,14,403,5642);
INSERT INTO purchase_invoice_items(invoice_id,item_id,qty,rate,amount) VALUES(30,6,17,72,1224);
UPDATE purchase_invoice SET total=6866 WHERE id=30;