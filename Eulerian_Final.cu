#include <iostream>
#include <cstdlib>
#include <ctime>
#include <cmath>
#include <chrono> 
using namespace std;

void checkArrays(int arr1[], int arr2[], int N) {
    int res = 0;
    for (int i = 0; i < N; i++) {
        res = (arr1[i] ^ arr2[i]);
    }

    if (res == 0) {
        cout << "Same" << endl;
    } else {
        cout << "Not Same" << endl;
    }
}
int find(int parent[], int x) {
    if (parent[x] == x) return x;
    return parent[x] = find(parent, parent[x]);
}

void unite(int parent[], int rank[], int x, int y) {
    int rootX = find(parent, x);
    int rootY = find(parent, y);
    if (rootX != rootY) {
        if (rank[rootX] > rank[rootY]) {
            parent[rootY] = rootX;
        } else if (rank[rootX] < rank[rootY]) {
            parent[rootX] = rootY;
        } else {
            parent[rootY] = rootX;
            rank[rootX]++;
        }
    }
}

__global__ void list_ranking(int* d_vals1,int* d_vals2,int* d_rank1,int* d_rank2,int n)
{
    int tid=blockIdx.x*blockDim.x+threadIdx.x;
    if(tid<n){
        d_rank2[tid]=d_rank1[tid]+d_rank1[d_vals1[tid]];
        d_vals2[tid]=d_vals1[d_vals1[tid]];

    }
}

__global__ void d_parent(int d_N,int* d_final_rank,int* d_parent,int* d_arr1,int* d_arr2,int d_root)
{
    
    int tid = (blockIdx.x * blockDim.x)+threadIdx.x ;


    if (tid <d_N) {
        int edge1 = tid;
        int edge2 = tid + d_N - 1;


        if (d_final_rank[edge1] > d_final_rank[edge2]) {
            
            d_parent[d_arr2[tid]] = d_arr1[tid];
        } 
        else {
            d_parent[d_arr1[tid]] = d_arr2[tid];
        }
    }
    
    if (tid == 0) {
        d_parent[d_root] = -1;
    }




}
__global__ void d_Parallel_Eulerian2(int* d_succ, int d_edgeCount, int* d_vertex, int* d_edges, int d_root, int d_N) 
{
    int tid = (blockIdx.x * blockDim.x)+threadIdx.x ;
    if(tid<d_N)
    {
        int no_of_neighbours=d_vertex[tid+1]-d_vertex[tid],u,v,succ_val;
        int i=0;
        while(i<no_of_neighbours)
        {
            u=d_edges[d_vertex[tid]+i];
            v= (u + d_edgeCount) % (2 * d_edgeCount);
            if(d_vertex[tid+1]>d_vertex[tid]+i+1)
            {
                succ_val=d_edges[d_vertex[tid]+i+1];
                d_succ[v]=succ_val;

            }
            else{
                succ_val=d_edges[d_vertex[tid]];
                d_succ[v]=succ_val;
            }
            i++;
        }
    }

}






void Serial_Eulerian(int* succ,int edgeCount,int* vertex,int* edges,int* final_rank,int root,int N,int* arr1,int* arr2,int* parent)
{
    int vertex_val=1,edge1,edge2;

    for(int i=0;i<2*edgeCount;i++)
    {
        if(i>=vertex[vertex_val])
        {
            vertex_val++;
        }
        int x=edges[i];
        int succ_val= (x+edgeCount)%((2*edgeCount));
        
        if (i + 1 == vertex[vertex_val]) {
        succ[succ_val] = edges[vertex[vertex_val - 1]];
        }

         else
        {

            succ[succ_val]=edges[i+1];
        }
            

    }    


    int prev=edges[vertex[root]];
    final_rank[prev]=0;


    for(int i=1;i<2*edgeCount;i++)
    {
        
        final_rank[succ[prev]]=i;
        prev=succ[prev];
    }



    for(int i=0;i<N;i++)
    {
        edge1=i;
        edge2=i+N-1;
        if(final_rank[edge1]<final_rank[edge2])
        {
            parent[arr2[i]]=arr1[i];
        }
        else{
            parent[arr1[i]]=arr2[i];
        }
    }    

    parent[root]=-1;




}

void createCSR(int N,int arr1[],int arr2[],int edgeCount,int* vertex,int* edges)
{
    int index;

    for (int i = 0; i < N+1; i++) {
    vertex[i] = 0;
    }

    for (int i = 0; i < (2*N)-2; i++){
        vertex[arr1[i]+1]++;

    } 

    //PREFIX SUM BELOW

    for (int i = 1; i < N+1; i++) {
    vertex[i] += vertex[i - 1];
    }

    for (int i = 0; i < 2*edgeCount+2; i++) {
    edges[i] = -1;
    }

    for(int i=0;i<2*N-2;i++)
    {
        index= vertex[arr1[i]];
        while(edges[index]!=-1)
        {
            index++;
        }
        edges[index]=i;
    }





    



}


void generateTree(int N, int root,int* arr1,int* arr2,int* parentArray,int* parent) {



    int* rank = new int[N]();



    for (int i = 0; i < N; i++) {
        parent[i] = i;
        parentArray[i] = -1;
    }

    srand(time(0));


    int edgeIndex = 0;
    int firstChild = (root + 1) % N;
    arr1[edgeIndex] = root;
    arr2[edgeIndex] = firstChild;
    arr1[edgeIndex+(N-1)] = firstChild;
    arr2[edgeIndex+(N-1)] = root;
    parentArray[firstChild] = root;
    unite(parent, rank, root, firstChild);
    edgeIndex++;


    for (int i = 0; i < N; i++) {
        if (i == root || i == firstChild) continue; 

        int parentVertex = rand() % N;
        while (find(parent, i) == find(parent, parentVertex) || parentArray[i] != -1 || parentVertex == i) {
            parentVertex = rand() % N; 
        }

        arr1[edgeIndex] = parentVertex;
        arr2[edgeIndex] = i;
        arr1[edgeIndex+(N-1)] = i;
        arr2[edgeIndex+(N-1)] = parentVertex;
        parentArray[i] = parentVertex;;
        unite(parent, rank, parentVertex, i);
        edgeIndex++;
    }




    free(rank);



}

int main() {
    int N, root;
    cout << "Enter the number of vertices: ";
    cin >> N;
    cout << "Enter the root vertex: ";
    cin >> root;


    int* arr1 = new int[2*(N - 1)];          
    int* arr2 = new int[2*(N - 1)];
    int* actual_parent = new int[N]; 
    int* parent = new int[N]; 

    int edgeCount=N-1;

    /*
    GENERATE TREE HERE
    */

    generateTree(N, root,arr1,arr2,actual_parent,parent);

    int* vertex= new int [N+2];
    int* edges = new int[2*edgeCount] ();
    int* final_rank_serial=new int[2*edgeCount] ();
    int* final_rank=new int[2*edgeCount] ();



    createCSR(N,arr1,arr2,edgeCount,vertex,edges); // CREATING CSE

    int* succ_serial = new int[2 * edgeCount]();
    int* succ = new int[2 * edgeCount]();
    int* serial_euiler_parent= new int [N];
    int* parallel_euiler_parent= new int [N];
 
    /*
    SERIAL EXECUTION HERE
    */
    auto start_serial = std::chrono::high_resolution_clock::now();
    Serial_Eulerian(succ_serial, edgeCount, vertex, edges,  final_rank_serial, root, N, arr1, arr2, serial_euiler_parent);
    auto end_serial = std::chrono::high_resolution_clock::now();
    auto duration_serial = std::chrono::duration_cast<std::chrono::nanoseconds>(end_serial - start_serial);
    long long serial_time = duration_serial.count();  // Time in milliseconds
    std::cout << "Serial Execution Time: " << serial_time << " ns" << std::endl;


    int* d_succ1 = nullptr;         // Device pointer for successor array
    int* d_succ2 = nullptr;
    int* d_edgeCount = nullptr;    // Device pointer for edge count
    int* d_vertex = nullptr;       // Device pointer for vertex array
    int* d_edges = nullptr;        // Device pointer for edges array
    int* d_parallel_euiler_parent= nullptr;
    int* d_final_rank1=nullptr;
    int* d_final_rank2=nullptr;
    int* d_arr1=nullptr;
    int* d_arr2=nullptr;
    int* h_parallel_euiler_parent = new int[N];  // Allocate memory for host array



    if(cudaMalloc((void **)&d_succ1,2*edgeCount*sizeof(int))!=cudaSuccess) printf("Error allocationg d_suc");
    if(cudaMalloc((void **)&d_succ2,2*edgeCount*sizeof(int))!=cudaSuccess) printf("Error allocationg d_suc");
    if(cudaMalloc((void **)&d_parallel_euiler_parent,N*sizeof(int))!=cudaSuccess) printf("Error allocationg parallel_euiler_parent");
    if(cudaMalloc((void **)&d_edgeCount,1*sizeof(int))!=cudaSuccess) printf("Error allocationg d_edgeCount");
    if(cudaMalloc((void **)&d_vertex,(N+2)*sizeof(int))!=cudaSuccess) printf("Error allocationg d_vertex");
    if(cudaMalloc((void **)&d_edges,2*edgeCount*sizeof(int))!=cudaSuccess) printf("Error allocationg d_edges");
    if(cudaMalloc((void **)&d_final_rank1,2*edgeCount*sizeof(int))!=cudaSuccess) printf("Error allocationg d_edges");
    if(cudaMalloc((void **)&d_final_rank2,2*edgeCount*sizeof(int))!=cudaSuccess) printf("Error allocationg d_edges");
    if(cudaMalloc((void **)&d_arr1,2*(N-1)*sizeof(int))!=cudaSuccess) printf("Error allocationg d_edges");
    if(cudaMalloc((void **)&d_arr2,2*(N-1)*sizeof(int))!=cudaSuccess) printf("Error allocationg d_edges");


    cudaMemcpy(d_succ1, succ, 2 * edgeCount * sizeof(int), cudaMemcpyHostToDevice);
    //cudaMemcpy(d_parallel_euiler_parent, parallel_euiler_parent, N * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_vertex, vertex, (N + 2) * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_edges, edges, 2 * edgeCount * sizeof(int), cudaMemcpyHostToDevice);
    //cudaMemcpy(d_final_rank1, final_rank, 2 * edgeCount * sizeof(int), cudaMemcpyHostToDevice);
    //cudaMemcpy(d_arr1, arr1, 2 * (N - 1) * sizeof(int), cudaMemcpyHostToDevice);
    //cudaMemcpy(d_arr2, arr2, 2 * (N - 1) * sizeof(int), cudaMemcpyHostToDevice);


    cudaEvent_t start_parallel, stop_parallel;
    cudaEventCreate(&start_parallel);
    cudaEventCreate(&stop_parallel);

    cudaEventRecord(start_parallel);
    /*
    Calculating successor here
    */
    int blockSize = 1024;
    int numBlocks = (edgeCount + blockSize - 1) / blockSize;  
    d_Parallel_Eulerian2<<<numBlocks, blockSize>>>(d_succ1, edgeCount, d_vertex, d_edges, root, N);
    cudaDeviceSynchronize();
    cudaMemcpy(succ,d_succ1,2*edgeCount*sizeof(int),cudaMemcpyDeviceToHost);
    
    cudaFree(d_vertex);
    cudaFree(d_edges);


    
    int last_edge=edges[vertex[root+1]-1];
    last_edge=last_edge+N-1;


    for(int i=0;i<2*edgeCount;i++)
    {
        final_rank[i]=1;
    }
    succ[last_edge] =last_edge ;
    final_rank[last_edge]=0;



    int loop=log(N);
    loop=loop+10;;

    cudaMemcpy(d_final_rank1,final_rank,2*edgeCount*sizeof(int),cudaMemcpyHostToDevice);
    cudaMemcpy(d_succ1,succ,2*edgeCount*sizeof(int),cudaMemcpyHostToDevice);

    for(int i=0;i<loop;i++)
    {
        if(i%2==0)
        {
            list_ranking<<<numBlocks,blockSize>>>(d_succ1,d_succ2,d_final_rank1,d_final_rank2,2*edgeCount);

        }
        else
        {
            list_ranking<<<numBlocks,blockSize>>>(d_succ2,d_succ1,d_final_rank2,d_final_rank1,2*edgeCount);
        }
        cudaDeviceSynchronize();
    }

    cudaMemcpy(final_rank,d_final_rank2,2*edgeCount*sizeof(int),cudaMemcpyDeviceToHost);
    //cudaMemcpy(succ,d_succ2,2*edgeCount*sizeof(int),cudaMemcpyDeviceToHost);
    //free(d_succ1);

    cudaMemcpy(d_arr1, arr1, 2 * (N - 1) * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_arr2, arr2, 2 * (N - 1) * sizeof(int), cudaMemcpyHostToDevice);

    cudaMemcpy(d_final_rank1,final_rank,2*edgeCount*sizeof(int),cudaMemcpyHostToDevice);

    d_parent<<<numBlocks, blockSize>>>(N,d_final_rank1,d_parallel_euiler_parent,d_arr1,d_arr2,root);

    cudaDeviceSynchronize();
    cudaMemcpy(parallel_euiler_parent,d_parallel_euiler_parent,N*sizeof(int),cudaMemcpyDeviceToHost);
    cudaEventRecord(stop_parallel);
    cudaEventSynchronize(stop_parallel);

    float parallel_time_float;
    cudaEventElapsedTime(&parallel_time_float, start_parallel, stop_parallel);  // Time in milliseconds

    // Convert to nanoseconds
    long long parallel_time_ns = static_cast<long long>(parallel_time_float * 1e6);  // 1 ms = 1e6 ns

    std::cout << "Serial Execution Time: " << serial_time << " ns" << std::endl;

    std::cout << "Parallel Execution Time: " << parallel_time_ns << " ns" << std::endl;


    checkArrays(actual_parent,serial_euiler_parent,N);
    checkArrays(actual_parent,parallel_euiler_parent,N);

    



    // free(edges);
    free(arr1);
    free(arr2);
    free(parent);
    free(actual_parent);

    // free(final_rank);
    free(succ);
    free(serial_euiler_parent);
    free(parallel_euiler_parent);

    return 0;
}