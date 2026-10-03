import 'learning_hub_models.dart';

Course buildDefaultSpringBootCourse() {
  const mod1Title = 'MongoDB & REST API Architecture';
  const mod2Title = 'Security, Profiles & Testing Architecture';
  const mod3Title = 'Advanced APIs, Clean Code & Internals';
  const mod4Title = 'Foundations, Annotations & Production Crons';

  // Module 1: MongoDB & REST API Architecture (9 lectures: items 10 to 18)
  final mod1Lectures = [
    const Lecture(
      id: 1,
      moduleId: 1,
      moduleTitle: mod1Title,
      title: "A Beginner's Walkthrough to MongoDB: Key Concepts Simplified",
      durationSeconds: 350, // 05:50
    ),
    const Lecture(
      id: 2,
      moduleId: 1,
      moduleTitle: mod1Title,
      title: "Understanding ORM, JPA, and Spring Data JPA: A Step-by-Step Tutorial",
      durationSeconds: 611, // 10:11
    ),
    const Lecture(
      id: 3,
      moduleId: 1,
      moduleTitle: mod1Title,
      title: "Step-by-Step Tutorial: How to Integrate MongoDB in Your Spring Boot Application",
      durationSeconds: 1822, // 30:22
    ),
    const Lecture(
      id: 4,
      moduleId: 1,
      moduleTitle: mod1Title,
      title: "ResponseEntity in Spring Boot in Hindi | Handling HttpStatus while creating REST API",
      durationSeconds: 1072, // 17:52
    ),
    const Lecture(
      id: 5,
      moduleId: 1,
      moduleTitle: mod1Title,
      title: "Mastering Project Lombok in Java: Simplify Your Code Like a Pro",
      durationSeconds: 365, // 06:05
    ),
    const Lecture(
      id: 6,
      moduleId: 1,
      moduleTitle: mod1Title,
      title: "Mastering MongoDB Relationships in Spring Boot: @DBRef Annotation for Seamless...",
      durationSeconds: 2667, // 44:27
    ),
    const Lecture(
      id: 7,
      moduleId: 1,
      moduleTitle: mod1Title,
      title: "@Transactional Annotation in Spring Boot Example in Hindi |...",
      durationSeconds: 1015, // 16:55
    ),
    const Lecture(
      id: 8,
      moduleId: 1,
      moduleTitle: mod1Title,
      title: "Connecting Spring Boot to MongoDB Atlas: A Step-by-Step Tutorial",
      durationSeconds: 606, // 10:06
    ),
    const Lecture(
      id: 9,
      moduleId: 1,
      moduleTitle: mod1Title,
      title: "One-Stop Solution: Installing MongoDB on Mac, Lubuntu, Fedora, Windows 11",
      durationSeconds: 579, // 09:39
    ),
  ];

  // Module 2: Security, Profiles & Testing Architecture (8 lectures: items 19 to 26)
  final mod2Lectures = [
    const Lecture(
      id: 10,
      moduleId: 2,
      moduleTitle: mod2Title,
      title: "This video is for users of Spring Boot versions other than the one covered in the lectures",
      durationSeconds: 75, // 01:15
    ),
    const Lecture(
      id: 11,
      moduleId: 2,
      moduleTitle: mod2Title,
      title: "Spring Security in Spring Boot in Hindi | @EnableWebSecurity Annotation",
      durationSeconds: 2980, // 49:40
    ),
    const Lecture(
      id: 12,
      moduleId: 2,
      moduleTitle: mod2Title,
      title: "Adding Authentication to Journal Endpoints",
      durationSeconds: 1263, // 21:03
    ),
    const Lecture(
      id: 13,
      moduleId: 2,
      moduleTitle: mod2Title,
      title: "Role Based Authorization in Spring Boot Project",
      durationSeconds: 838, // 13:58
    ),
    const Lecture(
      id: 14,
      moduleId: 2,
      moduleTitle: mod2Title,
      title: "Properties | YAML | How to pass command line arguments in spring boot application ?",
      durationSeconds: 758, // 12:38
    ),
    const Lecture(
      id: 15,
      moduleId: 2,
      moduleTitle: mod2Title,
      title: "JUnit Testing in Spring Boot | @Test @ParameterizedTest @CsvSource...",
      durationSeconds: 1726, // 28:46
    ),
    const Lecture(
      id: 16,
      moduleId: 2,
      moduleTitle: mod2Title,
      title: "Mockito Spring Boot Tutorial | @Mock @InjectMocks",
      durationSeconds: 833, // 13:53
    ),
    const Lecture(
      id: 17,
      moduleId: 2,
      moduleTitle: mod2Title,
      title: "Master Spring Boot Profiles: A Comprehensive Guide for Developers - 2026 Update",
      durationSeconds: 1158, // 19:18
    ),
  ];

  // Module 3: Advanced APIs, Clean Code & Internals (9 lectures: items 27 to 35)
  final mod3Lectures = [
    const Lecture(
      id: 18,
      moduleId: 3,
      moduleTitle: mod3Title,
      title: "Mastering Logging in Spring Boot: A Complete Guide, from Logback to SLF4J",
      durationSeconds: 2178, // 36:18
    ),
    const Lecture(
      id: 19,
      moduleId: 3,
      moduleTitle: mod3Title,
      title: "Master SonarQube, SonarLint, and SonarCloud: Ultimate Guide to Enhancing Your Code Quality",
      durationSeconds: 1143, // 19:03
    ),
    const Lecture(
      id: 20,
      moduleId: 3,
      moduleTitle: mod3Title,
      title: "Master External API Integration in Spring Boot: A Step-by-Step Guide",
      durationSeconds: 1275, // 21:15
    ),
    const Lecture(
      id: 21,
      moduleId: 3,
      moduleTitle: mod3Title,
      title: "Spring Boot Tutorial: How to Consume External POST APIs Effectively",
      durationSeconds: 577, // 09:37
    ),
    const Lecture(
      id: 22,
      moduleId: 3,
      moduleTitle: mod3Title,
      title: "Ultimate Guide to Using Eleven Labs API: Transform Text to Lifelike Speech in Minutes!",
      durationSeconds: 908, // 15:08
    ),
    const Lecture(
      id: 23,
      moduleId: 3,
      moduleTitle: mod3Title,
      title: "@component vs @service in Spring Boot",
      durationSeconds: 190, // 03:10
    ),
    const Lecture(
      id: 24,
      moduleId: 3,
      moduleTitle: mod3Title,
      title: "Mastering @Value in Spring Boot: Inject Properties Like a Pro!",
      durationSeconds: 426, // 07:06
    ),
    const Lecture(
      id: 25,
      moduleId: 3,
      moduleTitle: mod3Title,
      title: "Mastering @PostConstruct in Spring Boot: Complete Guide for Developers",
      durationSeconds: 1219, // 20:19
    ),
    const Lecture(
      id: 26,
      moduleId: 3,
      moduleTitle: mod3Title,
      title: "Mastering MongoTemplate, Criteria, and Query in Spring Boot MongoDB",
      durationSeconds: 1476, // 24:36
    ),
  ];

  // Module 4: Foundations, Annotations & Production Crons (11 lectures: items 1 to 9, 36, 37)
  final mod4Lectures = [
    const Lecture(
      id: 27,
      moduleId: 4,
      moduleTitle: mod4Title,
      title: "What is Spring Boot in Hindi | The Whys and Hows of this Java Marvel!",
      durationSeconds: 678, // 11:18
    ),
    const Lecture(
      id: 28,
      moduleId: 4,
      moduleTitle: mod4Title,
      title: "Install Java & IntelliJ on Windows 11",
      durationSeconds: 385, // 06:25
    ),
    const Lecture(
      id: 29,
      moduleId: 4,
      moduleTitle: mod4Title,
      title: "You can download Spring Boot Project from the zip file in the description",
      durationSeconds: 164, // 02:44
    ),
    const Lecture(
      id: 30,
      moduleId: 4,
      moduleTitle: mod4Title,
      title: "Create Spring Boot Project in IntelliJ | Create Spring Boot Project with Spring Initializr",
      durationSeconds: 598, // 09:58
    ),
    const Lecture(
      id: 31,
      moduleId: 4,
      moduleTitle: mod4Title,
      title: "Install maven on windows 11",
      durationSeconds: 105, // 01:45
    ),
    const Lecture(
      id: 32,
      moduleId: 4,
      moduleTitle: mod4Title,
      title: "What is Maven in Java in Hindi | How Maven Works with Java & Spring Boot: Step-by-Step...",
      durationSeconds: 613, // 10:13
    ),
    const Lecture(
      id: 33,
      moduleId: 4,
      moduleTitle: mod4Title,
      title: "Structure of Spring Boot Application | What's Inside Your Spring Boot App?",
      durationSeconds: 572, // 09:32
    ),
    const Lecture(
      id: 34,
      moduleId: 4,
      moduleTitle: mod4Title,
      title: "@SpringBootApplication Internal Working | IOC Container & Dependency Injection in Spring...",
      durationSeconds: 1421, // 23:41
    ),
    const Lecture(
      id: 35,
      moduleId: 4,
      moduleTitle: mod4Title,
      title: "Creating REST API using Spring Boot in Hindi | A Step-by-Step Tutorial",
      durationSeconds: 1636, // 27:16
    ),
    const Lecture(
      id: 36,
      moduleId: 4,
      moduleTitle: mod4Title,
      title: "Send Email Using Spring Boot | Gmail SMTP | Java Mail Sender",
      durationSeconds: 795, // 13:15
    ),
    const Lecture(
      id: 37,
      moduleId: 4,
      moduleTitle: mod4Title,
      title: "Ultimate Guide to Scheduling Tasks with Cron Jobs in Spring Boot",
      durationSeconds: 862, // 14:22
    ),
  ];

  final modules = [
    CourseModule(
      id: 1,
      title: mod1Title,
      description: 'Core REST architecture, MongoDB setup, schemas, and Atlas cluster integration',
      durationHours: 2.4,
      lectures: mod1Lectures,
    ),
    CourseModule(
      id: 2,
      title: mod2Title,
      description: 'Spring Security 6, JWT, User Auth, Profiles, JUnit & Mockito test suites',
      durationHours: 3.3,
      lectures: mod2Lectures,
    ),
    CourseModule(
      id: 3,
      title: mod3Title,
      description: 'External API integrations, Lombok, SLF4J logging, SonarQube & MongoTemplate',
      durationHours: 2.2,
      lectures: mod3Lectures,
    ),
    CourseModule(
      id: 4,
      title: mod4Title,
      description: 'Foundations, Maven, IOC Container, Email integration, and production Crons',
      durationHours: 2.8,
      lectures: mod4Lectures,
    ),
  ];

  return Course(
    id: 'spring_boot_mastery',
    title: 'Spring Boot Mastery: From Basics to Production',
    description: 'Comprehensive Spring Boot, Microservices, Security, Kafka, and Production Deployment curriculum.',
    author: 'Engineering Digest',
    daysLeft: 31,
    targetMinutesPerDay: 28,
    modules: modules,
  );
}
