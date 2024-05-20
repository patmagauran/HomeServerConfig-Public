# Setting up a Zero-Trust Docker based Home Server

# Part 1 - Introduction

My home server setup has grown organically over many years now. Throughout these changes I focused on integrating additional security and reliability features. In this multi-part article series, I plan to explain my setup and allow others to replicate it for their own usage. 

Although it grew organically, I have kept a relatively consistent set of goals:
    - Run any service I desire with minimal time to setup
    - Allow those services to be accessed securely by trusted users
    - Prevent any breach of any component from proliferating to other services or parts of my network
    - Stay as efficient as possible

To make this happen, I have a few key technologies that are important to conceptually understand before implementing them: Docker(Containerization) + Docker Compose, ZeroTier(P2P VPN), Traefik(Reverse Proxy), Oauth(Authentication services), Git, Vlans/Network terms, DNS, Cloudflare(Serves as public access point for services), and Linux(Debian specifically).  I will explain each of them below. You may skip over any section in which you already are familiar; however I will also be explaining their exact purpose in relation to this project. Throughout the other parts I will focus primarily on how to leverage them to meet the goals above without going into their background/philosphies.

## Docker, Docker Compose, and Containers
Docker is the core of this project. It is one of the most common ways to run containers, which can be thought of as a form of para-virtualization. This allows each container to see itself as running its own OS, with its own processes, file-system, and security protocols without access to any part of the host system(Or other containers!) that has not been explicitly granted. This is very important for my goals. It means that each service I run is isolated from every other service and from the host machine.

Historically, this would be accomplished using a virtual machine hypervisor(And previous iterations of my setup did just that) such as VMWare EXsi, QEMU/libvirt, VirtualBox, Microsoft Hyper-V, etc. However, those systems (generally) perform full-virtualization wherein each guest is given its own virtual computer. This imposes fixed performance penalities as hardware needs to be emulated and system resource allocations are fixed rather than flexible.

In contrast, every container shares the same kernel and hardware, eliminating that emulation layer and performance penalty. Therefore all the processes in a container run in the host. This can be a major security concern but major work has been put into creating the isolation layers for these processes so that they are effectively running on their own machine. Even still, due to the concern of a process "breaking out" of its container, there are features known as "rootless" containers or user-namespace remapped containers which alter the user running the container's processes to not map to any user on the host machine. This means that there would be a second layer of security for an attacker to penetrate. They would have to break out of the container and then execute a privelege escalation attack. Neither of these are trivial and there are even further layers that we will be implementing such as running the processes as non-root in the container themselves(+1 layer - another privelege escalation), and isolating services from the network(+1 layer).

So we will be using containers, which to summarize are isolated mini operating systems running whatever processes we want. In order to configure and orchestrate these containers we will use Docker Compose, which is a YAML(Yet Another Markup Language) file based configuration manager. Once the files are created, it is as simple as running one of a few different commands to start, stop, restart, pull new images both the entire stack or just one container. There are a few additional more advanced features of the compose specification that we will be using, but I will explain those as we come across them. Compose gives us repeatability and flexibility. It means it is very easy to add a new service, change the settings on an existing service, or migrate an entire setup to a new machine without creating a bunch of scripts.

## ZeroTier / P2P VPN
ZeroTier is a very easy to use peer to peer VPN service. This allows you to create networks of machines that can all act as if they are on the same local network. It is very low overhead compared to a full VPN client/server setup and very simple to setup. This is a critical componet to achieve goal 2.

I also want to point out that there are quite a few different products that offer this functionality. I settled on ZeroTier and it has not caused me any problems; however I have not researched the other options recently to see if they have new features that would be better. For those who are concerned about putting trust in any company and would rather self host, there are options available to run your own P2P VPN. However, in order to handle client IP changes and other issues there needs to be a central server somewhere which is publically accessible. I decided the security trade off was worth it as their servers do not process any of the VPN traffic unless there are routing issues(and even then it remains encrypted).

## Traefik / Reverse Proxies
A reverse proxy serves as a public entrypoint to your set of services and forwards those requests to the appropriate service based on a set of rules. This provides a few advantages: no need to worry about port allocations, only one endpoint to protect with HTTPS and authentication, and easy URL based routing. Traefik is just one tool to do this, but it is designed for our use case: running a bunch of services in containers. It will automatically pick up new containers and begin routing them if you configure it to do so. This makes adding/changing services much easier than using other more static solutions such as nginx. It is also extremely well supported and used by enterprises globally. 

## Oauth
OAuth allows us to require authentication to access our services without needing to setup our own authentication system. Oauth is the technology that allows the "Sign in with (Google, Facebook, Microsoft, etc.)" that is in place all over the internet. In our case we will be using Google's OAuth systems, but it is just as easy to integrate with any provider you choose(Even your own).

## Linux
Our hosts will be Debian based linux. I assume you are familiar with basic bash terminal usage. If not, please find a beginners to linux tutorial. I will give most of the commands that will be needed, but it will be important to at least do the following: Navigate a directory tree, install software, create, edit, and delete files. A basic understanding of the linux permissions and user system will be useful as well. I chose Debian as it what I am familiar with; however any linux distro will work just fine as long as you are comfortable with it.

## Git
Git is a type of Version Control Software(VCS). This allows us to track changes to files related to our services, store them remotely, and sync those changes to other hosts as needed. A basic understanding of git will be useful to assist with more than one host or undoing any mistakes or breaking changes you may make. Understand though that Git is not intended as a backup solution. It is designed to handle changes in text files, not large amounts of non-text data.

## The other technologies
Above I covered the main technologies that will allow us to perform our work. There is not much to say about the remaining technologies that won't be just throwing a bunch of vocabulary at you. For these small topics I will give brief definitions as appropriate. 

# My network plan
This is a lot of technology to run for what ends up being a few personal services and a nextcloud instance. However, It means I have very little worry about the reliability of anything and more imporantly that it is portable and efficient. I currently have 2 systems running. One system is an old laptop that runs 24/7 and hosts some always on services and core services. The other is a more powerful desktop with my mirrored RAID array for my nextcloud and backup system. This system is setup to turn on for a few hours weekly for updates and disk checks. Otherwise I only turn it on as needed via Wake on Lan. This saves a significant amount of power that would otherwise be wasted just idling. 

# Moving onto part 2
I hope that was able to give you a good understanding of what will be accomplished in this series and the knowledge you should have / you will ultimately learn. In part 2, I will discuss setting up a host from scratch to host the core infrastructure needed for everything else. 

[Next Part - Prerequisites](./Part1.5-Prerequisites.md)