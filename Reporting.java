import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Scanner;

/* ++++++++++++++++++++++++++++++++++++++++++++++
  Make sure you did the following before execution
     1) Log in to CCC machine using your WPI account

     2) Set environment variables using the following command
       > source /cs/bin/oracle-setup

     3- Set CLASSPATH for java using the following command
       > export CLASSPATH=./:/usr/local/oracle11gr203/product/11.2.0/db_1/jdbc/lib/ojdbc6.jar

     4- Write your java code (say file name is OracleTest.java) and then compile it using the  following command
       > /usr/local/bin/javac OracleTest.java

     5- Run it
        > /usr/local/bin/java OracleTest
  ++++++++++++++++++++++++++++++++++++++++++++++  */

public class Reporting {
	public static void reportPatient(Connection conn) {
		// Christian Tweed
		String ssn; // the select var
		boolean r = false; // is there a result
		// initializing the scanner
		Scanner scan;
		System.out.println("Enter Patient SSN: ");
		scan = new Scanner(System.in);
		ssn = scan.next();
		try {
			PreparedStatement ps = conn.prepareStatement("SELECT * FROM patients WHERE ssn=?");
			ps.setString(1, ssn);
			ResultSet rs = ps.executeQuery();
			while (rs.next()) {
				String rssn = rs.getString("ssn");
				String fname = rs.getString("firstname");
				String lname = rs.getString("lastname");
				String addr = rs.getString("address");
				String tel = rs.getString("telnum");
				String result = "SSN: " + rssn + "\nFirst Name :" + fname + "\nLast Name :" + lname + "\nAddress :"
						+ addr + "\nTelephone Number: " + tel;
				System.out.println(result);
			}
			rs.close();
		} catch (SQLException e) {
			// caught the issue
			e.printStackTrace();
		}

	}

	public static void defaultResponse(Connection conn) {
		System.out.println("Default argument");
		System.out.println("1- Report Patients Basic Information");
		System.out.println("2- Report Docotors Basic Information");
		System.out.println("3- Report Admissions Information");
		System.out.println("4- Update Admissions Payment");
	}

	public static void reportDoctor(Connection conn) {
		// Christian Tweed
		String id; // the select var
		boolean r = false; // is there a result
		// initializing the scanner
		Scanner scan;
		System.out.println("Enter Doctor ID: ");
		scan = new Scanner(System.in);
		id = scan.nextLine();
		try {
			PreparedStatement ps = conn.prepareStatement("SELECT * FROM doctor WHERE id = ?");
			ps.setString(1, id);
			ResultSet rs = ps.executeQuery();
			while (rs.next()) {
				String did = rs.getString("id");
				String dgender = rs.getString("gender");
				String ds = rs.getString("specialty");
				String dlname = rs.getString("lastname");
				String dfname = rs.getString("firstname");
				String result = "Doctor id :" + did + "\nGender :" + dgender + "\nSpecialty :" + ds + "\nLast Name : "
						+ dlname + "\nFirst Name :" + dfname;
				System.out.println(result);
			}
			rs.close();
		} catch (SQLException e) {
			// caught the issue
			e.printStackTrace();
		}
	}

	public static void reportAdmission(Connection conn) {
		System.out.println("Choice 3 selected");
		Scanner sc = new Scanner(System.in);

		System.out.println("Entter an Admission Number: ");
		int userInput = sc.nextInt();
		sc.close();
		try {
			PreparedStatement ps = conn.prepareStatement("SELECT * FROM admission WHERE admissionnum=?");
			ps.setInt(1, userInput);
			// Make sure to catch null input
			ResultSet rs = ps.executeQuery();
			while (rs.next()) {

				String pssn = rs.getString("patientssn");
				String aDate = rs.getString("admissiondate");
				Double totalPayment = rs.getDouble("totalpayment");
				System.out.println("Admission Number:	 " + userInput + "\nPatient SSN: " + pssn + "\nAdmission Date: "
						+ aDate + "\nTotal Payment: " + totalPayment);

			}

			ps = conn.prepareStatement("SELECT * FROM stayin WHERE admissionnum=?");
			ps.setInt(1, userInput);

			rs = ps.executeQuery();
			System.out.println("Rooms:");
			while (rs.next()) {
				int roomnum = rs.getInt("roomnum");
				String startDate = rs.getString("startdate");
				String endDate = rs.getString("enddate");

				System.out.println("Room Num: " + roomnum + " From Date: " + startDate + " End Date: " + endDate);
			}
			ps = conn.prepareStatement("SELECT * FROM examine WHERE admissionnum=?");
			ps.setInt(1, userInput);

			rs = ps.executeQuery();
			System.out.println("Doctors examined the patient in this admission:");
			while (rs.next()) {
				String doctorid = rs.getString("doctorid");
				System.out.println("Doctor ID: " + doctorid);
			}

		} catch (SQLException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
	}

	public static void updateAdmission(Connection conn) {
		int addnum; // the admission num
		int tpay; // the new total payment
		// Scanning
		Scanner scan = new Scanner(System.in);
		;
		System.out.println("Enter Admission Num: ");
		addnum = scan.nextInt();
		System.out.println("Enter New Total Payment: ");
		tpay = scan.nextInt();
		// Accessing the database
		try {
			PreparedStatement ps = conn
					.prepareStatement("UPDATE admission SET totalpayment = ? WHERE admissionnum = ?");
			ps.setInt(1, tpay);
			ps.setInt(2, addnum);
			int r = ps.executeUpdate();
			if (r == 0) {
				System.out.println("There were no updates rows");
			} else {
				System.out.println("Update Completed");
			}
		} catch (SQLException e) {
			e.printStackTrace();
		}
	}

	public static void main(String[] argv) throws SQLException {
		String user = argv[0];

		String pass = argv[1];
		String selection = "";
		if (argv.length == 3) {
			selection = argv[2];
		}
		System.out.println("Length: " + argv.length);
		System.out.println("User: " + user);
		System.out.println("Pass: " + pass);
		System.out.println("Selection: " + selection);
		System.out.println("-------- Oracle JDBC Connection Testing ------");
		System.out.println("-------- Step 1: Registering Oracle Driver ------");
		try {
			Class.forName("oracle.jdbc.driver.OracleDriver");
		} catch (ClassNotFoundException e) {
			System.out.println("Where is your Oracle JDBC Driver? Did you follow the execution steps. ");
			System.out.println("");
			System.out.println("*****Open the file and read the comments in the beginning of the file****");
			System.out.println("");
			e.printStackTrace();
			return;
		}
		System.out.println("Oracle JDBC Driver Registered Successfully !");

		System.out.println("-------- Step 2: Building a Connection ------");
		Connection connection = null;
		try {
			connection = DriverManager.getConnection("jdbc:oracle:thin:@oracle.wpi.edu:1521:orcl", user, pass);

		} catch (SQLException e) {
			System.out.println("Connection Failed! Check output console");
			e.printStackTrace();
			return;
		}

		if (connection != null) {
			System.out.println("You made it. Connection is successful. Take control of your database now!");
			System.out.println("Selection " + selection + " will be made!");
			if (argv.length == 2) {
				defaultResponse(connection);
			} else if (argv.length > 2) {
				System.out.println("Non-default repsonse incoming");
				if (selection.equals("1")) {
					System.out.println("Choice 1 selected!");
					reportPatient(connection);
				} else if (selection.equals("2")) {
					reportDoctor(connection);
				} else if (selection.equals("3")) {
					reportAdmission(connection);
				}
				else if(selection.equals("4")) {
					updateAdmission(connection);
				}
			}

		} else {
			System.out.println("Failed to make connection!");
		}
		connection.close();
	}

}